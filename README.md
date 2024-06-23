# Networking

Networking layer that supports completion handlers, Combine and async/await.

## Installation via SPM:

Go to Package Dependencies and add https://github.com/djalfirevic/ios-networking-layer

## Setup

Logging is enabled by default and if you want to disable it, you can just add a line:

```swift
APILogger.isLoggingEnabled = false
````

### Example:

```swift
import Foundation
import Networking

enum MainAPI: API {
    case photos

// MARK: - API

    var path: String {
        switch self {
            case .photos:
            return "/services/feeds/photos_public.gne"
        }
    }
    var parameters: [URLQueryItem] {
        switch self {
            case .photos:
                [
                    URLQueryItem(name: "tags", value: "priime"),
                    URLQueryItem(name: "format", value: "json"),
                    URLQueryItem(name: "nojsoncallback", value: "1"),
            ]
        }
    }
    var baseURL: String { "api.flickr.com" }
    var scheme: HTTPScheme { .https }
    var headerTypes: [HTTPHeaderField: String] {
        let headers: [HTTPHeaderField: String] = [
            .contentType: "application/json",
            .accept: "application/json"
        ]

        return headers
    }
    var method: HTTPMethod {
        switch self {
            case .photos:
                return .get
        }
    }
    var body: Data? {
        switch self {
            case .photos:
                return nil
        }
    }
}
```
Here, I've used a public Flickr API.

After that, if we define a simple `struct`:

```swift
struct FlickrResponse: Codable {

    // MARK: - Properties

    let title: String
    let link: String
}

```

We can make a request like this:

```swift
Task {
    do {
        let photos: FlickrResponse = try await NetworkManager.shared.request(endpoint: MainAPI.photos)
        print(photos.title)
    } catch {
        print("Error \(error.localizedDescription)")
    }
}
```

```swift
NetworkManager.shared.request(endpoint: MainAPI.photos) { (result: Result<FlickrResponse, APIError>) in
    switch result {
        case .success(let response):
            print(response.title)
        case .failure(let error):
            print("Error \(error.localizedDescription)")
    }
}
```