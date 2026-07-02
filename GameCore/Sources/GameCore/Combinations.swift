/// All combinations of `k` elements from `array`, preserving relative order.
func combinations<T>(_ array: [T], choose k: Int) -> [[T]] {
    guard k > 0 else { return [[]] }
    guard k <= array.count else { return [] }
    if k == array.count { return [array] }

    var result: [[T]] = []
    func helper(start: Int, current: [T]) {
        if current.count == k {
            result.append(current)
            return
        }

        let remainingCount = k - current.count
        let lastStart = array.count - remainingCount
        guard start <= lastStart else { return }
        for index in start...lastStart {
            helper(start: index + 1, current: current + [array[index]])
        }
    }
    helper(start: 0, current: [])
    return result
}
