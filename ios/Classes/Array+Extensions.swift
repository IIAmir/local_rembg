import Swift

extension Array where Element: Comparable {
  /**
    Returns the index and value of the largest element in the array.

    - Note: This method is slow. For faster results, use the standalone
            version of argmax() instead.
  */
  public func argmax() -> (Int, Element) {
    precondition(self.count > 0)
    var maxIndex = 0
    var maxValue = self[0]
    for i in 1..<self.count where self[i] > maxValue {
      maxValue = self[i]
      maxIndex = i
    }
    return (maxIndex, maxValue)
  }

  /**
    Returns the indices of the array's elements in sorted order.
  */
  public func argsort(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Array.Index] {
    return self.indices.sorted { areInIncreasingOrder(self[$0], self[$1]) }
  }

  /**
    Returns a new array containing the elements at the specified indices.
  */
  public func gather(indices: [Array.Index]) -> [Element] {
    return indices.map { self[$0] }
  }
}
