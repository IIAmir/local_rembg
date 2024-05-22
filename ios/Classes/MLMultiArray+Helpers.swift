import CoreML

extension MLMultiArray {
  /**
    Returns a new MLMultiArray with the specified dimensions.

    - Note: This does not copy the data but uses a pointer into the original
      multi-array's memory. The caller is responsible for keeping the original
      object alive, for example using `withExtendedLifetime(originalArray) {...}`
  */
  @nonobjc public func reshaped(to dimensions: [Int]) throws -> MLMultiArray {
    let newCount = dimensions.reduce(1, *)
    precondition(newCount == count, "Cannot reshape \(shape) to \(dimensions)")

    var newStrides = [Int](repeating: 0, count: dimensions.count)
    newStrides[dimensions.count - 1] = 1
    for i in stride(from: dimensions.count - 1, to: 0, by: -1) {
      newStrides[i - 1] = newStrides[i] * dimensions[i]
    }

    let newShape_ = dimensions.map { NSNumber(value: $0) }
    let newStrides_ = newStrides.map { NSNumber(value: $0) }

    return try MLMultiArray(dataPointer: self.dataPointer,
                            shape: newShape_,
                            dataType: self.dataType,
                            strides: newStrides_)
  }

  /**
    Returns a transposed version of this MLMultiArray.

    - Note: This copies the data.

    - TODO: Support .float32 and .int32 types too.
  */
  @nonobjc public func transposed(to order: [Int]) throws -> MLMultiArray {
    let ndim = order.count

    precondition(dataType == .double)
    precondition(ndim == strides.count)

    let newShape = shape.indices.map { shape[order[$0]] }
    let newArray = try MLMultiArray(shape: newShape, dataType: self.dataType)

    let srcPtr = UnsafeMutablePointer<Double>(OpaquePointer(dataPointer))
    let dstPtr = UnsafeMutablePointer<Double>(OpaquePointer(newArray.dataPointer))

    let srcShape = shape.map { $0.intValue }
    let dstStride = newArray.strides.map { $0.intValue }
    var idx = [Int](repeating: 0, count: ndim)

    for j in 0..<count {
      // Map the source index to the destination index.
      var dstIndex = 0
      for i in 0..<ndim {
        dstIndex += idx[order[i]] * dstStride[i]
      }

      // Copy the value.
      dstPtr[dstIndex] = srcPtr[j]

      // Update the source index.
      var i = ndim - 1
      idx[i] += 1
      while i > 0 && idx[i] >= srcShape[i] {
        idx[i] = 0
        idx[i - 1] += 1
        i -= 1
      }
    }
    return newArray
  }
}
