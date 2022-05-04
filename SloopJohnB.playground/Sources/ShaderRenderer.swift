import Foundation
import MetalKit

final public class ShaderRenderer: NSObject {
  public weak var device: MTLDevice?
  public var library: MTLLibrary?
  public var functionName: String? {
    didSet {
      guard let functionName = functionName else { return }

      guard let device = device else {
        assertionFailure("Metal Device is not defined.")
        return
      }

      guard let library = library else {
        assertionFailure("MetalLibrary is not defined.")
        return
      }

      guard let function = library.makeFunction(name: functionName) else {
        assertionFailure("Failed to create function named \(functionName)")
        return
      }

      do {
        computePipelineState = try device.makeComputePipelineState(function: function)
      } catch {
        assertionFailure("Failed to create computePipelineState: \(error)")
        return
      }
    }
  }

  private let commandQueue: MTLCommandQueue?
  private var computePipelineState: MTLComputePipelineState?
  private var startDate: Date = Date()

  private lazy var textureLoader: MTKTextureLoader? = {
    guard let device = device else { return nil }
    return MTKTextureLoader(device: device)
  }()

  public init(device: MTLDevice) {
    self.device = device
    library = device.makeDefaultLibrary()
    commandQueue = device.makeCommandQueue()
  }
}

extension ShaderRenderer: MTKViewDelegate {
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  public func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let computePipelineState = computePipelineState else {
      return
    }

    let inTexture1: MTLTexture?
    if let imageUrl = Bundle.main.url(forResource: "surf1", withExtension: "png") {
      inTexture1 = try? textureLoader?.newTexture(URL: imageUrl, options: nil)
    } else {
      inTexture1 = nil
    }

    let inTexture2: MTLTexture?
    if let imageUrl = Bundle.main.url(forResource: "surf2", withExtension: "png") {
      inTexture2 = try? textureLoader?.newTexture(URL: imageUrl, options: nil)
    } else {
      inTexture2 = nil
    }

    let threadsPerThreadgroup: MTLSize = MTLSize(width: 16, height: 16, depth: 1)
    var threadgroupCount: MTLSize {
      let width = Int(ceilf(Float(view.frame.width) / Float(threadsPerThreadgroup.width)))
      let height = Int(ceilf(Float(view.frame.height) / Float(threadsPerThreadgroup.height)))
      return MTLSize(width: width, height: height, depth: 1)
    }

    var time = Float(Date().timeIntervalSince(startDate))

    let commandBuffer = commandQueue?.makeCommandBuffer()
    let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
    commandEncoder?.setComputePipelineState(computePipelineState)
    commandEncoder?.setTexture(drawable.texture, index: 0)
    commandEncoder?.setTexture(inTexture1, index: 1)
    commandEncoder?.setTexture(inTexture2, index: 2)
    commandEncoder?.setBytes(&time, length: MemoryLayout<Float>.size * 1, index: 0)
    commandEncoder?.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
    commandEncoder?.endEncoding()

    commandBuffer?.present(drawable)
    commandBuffer?.commit()
  }
}
