import Foundation

enum HeatmapGridBuilder {
    static func buildGrid(
        from entries: [MouseHeatmapEntry],
        gridSize: Int = Constants.heatmapGridSize
    ) -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)

        for entry in entries {
            guard entry.bucketX >= 0,
                  entry.bucketY >= 0,
                  entry.bucketX < gridSize,
                  entry.bucketY < gridSize
            else { continue }
            grid[entry.bucketY][entry.bucketX] += entry.clickCount
        }

        return grid
    }
}
