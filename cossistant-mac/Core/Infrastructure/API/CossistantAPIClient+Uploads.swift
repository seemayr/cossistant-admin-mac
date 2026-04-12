import Foundation

extension CossistantAPIClient {
  func generateUploadURL(
    _ payload: DashboardSignedUploadRequest
  ) async throws -> DashboardSignedUploadResponse {
    try await request(method: "POST", path: "uploads/sign-url", body: payload)
  }

  func upload(
    data: Data,
    using signedUpload: DashboardSignedUploadResponse
  ) async throws {
    var request = URLRequest(url: signedUpload.uploadURL)
    request.httpMethod = "PUT"
    request.httpBody = data
    request.setValue(signedUpload.contentType, forHTTPHeaderField: "Content-Type")

    let (_, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
      throw CossistantAPIError.invalidResponse
    }
  }
}
