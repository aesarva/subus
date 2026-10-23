import Foundation

public enum HTTPError: Error, Equatable, Sendable {
    case status(Int), tooLarge, insecureRedirect, tooManyRedirects
}

public protocol HTTPClient: Sendable {
    func get(_ url: URL, timeout: TimeInterval, maxBytes: Int) async throws -> (data: Data, finalURL: URL)
}

/// Только https (включая каждый редирект), не более 3 редиректов, обрыв при превышении `maxBytes`.
public final class URLSessionHTTPClient: HTTPClient {
    public static let maxRedirects = 3

    private let configuration: URLSessionConfiguration

    public init(configuration: URLSessionConfiguration = .ephemeral) {
        self.configuration = configuration
    }

    public func get(_ url: URL, timeout: TimeInterval, maxBytes: Int) async throws -> (data: Data, finalURL: URL) {
        guard url.scheme?.lowercased() == "https" else { throw HTTPError.insecureRedirect }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let loader = Loader(maxBytes: maxBytes)
        let session = URLSession(configuration: configuration, delegate: loader, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                loader.start(session.dataTask(with: request), continuation: continuation)
            }
        } onCancel: {
            loader.cancel()
        }
    }
}

/// Состояние одного запроса. `@unchecked Sendable`: все изменяемые поля защищены `lock`.
private final class Loader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    typealias Result = (data: Data, finalURL: URL)

    private let maxBytes: Int
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<Result, any Error>?
    private var buffer = Data()
    private var redirects = 0
    private var failure: (any Error)?
    private var cancelled = false

    init(maxBytes: Int) { self.maxBytes = maxBytes }

    func start(_ task: URLSessionDataTask, continuation: CheckedContinuation<Result, any Error>) {
        lock.lock()
        self.task = task
        self.continuation = continuation
        let alreadyCancelled = cancelled
        lock.unlock()
        if alreadyCancelled { task.cancel() }
        task.resume()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    /// Запоминает первую ошибку (она же результат запроса).
    private func fail(_ error: any Error) {
        lock.lock()
        if failure == nil { failure = error }
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        lock.lock()
        redirects += 1
        let count = redirects
        lock.unlock()
        if count > URLSessionHTTPClient.maxRedirects {
            fail(HTTPError.tooManyRedirects)
            completionHandler(nil)
            task.cancel()
        } else if request.url?.scheme?.lowercased() != "https" {
            fail(HTTPError.insecureRedirect)
            completionHandler(nil)
            task.cancel()
        } else {
            completionHandler(request)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            fail(HTTPError.status(http.statusCode))
            completionHandler(.cancel)
        } else if response.expectedContentLength > Int64(maxBytes) {
            fail(HTTPError.tooLarge)
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        buffer.append(data)
        let exceeded = buffer.count > maxBytes
        if exceeded { buffer = Data() }
        lock.unlock()
        if exceeded {
            fail(HTTPError.tooLarge)
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        let outcome: Swift.Result<Result, any Error>
        if let failure {
            outcome = .failure(failure)
        } else if let error {
            outcome = .failure(error)
        } else if let url = task.response?.url ?? task.currentRequest?.url {
            outcome = .success((buffer, url))
        } else {
            outcome = .failure(URLError(.badServerResponse))
        }
        lock.unlock()
        continuation?.resume(with: outcome)
    }
}
