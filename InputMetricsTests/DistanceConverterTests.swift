import XCTest
@testable import InputMetrics

final class DistanceConverterTests: XCTestCase {

    // MARK: - pixelsToMeters

    func testPixelsToMetersZero() {
        XCTAssertEqual(DistanceConverter.pixelsToMeters(0), 0)
    }

    func testPixelsToMetersKnownValue() {
        // 4330 pixels = 1 meter (Constants.pixelsPerMeter)
        XCTAssertEqual(DistanceConverter.pixelsToMeters(4330), 1.0, accuracy: 0.001)
    }

    func testPixelsToMetersLargeValue() {
        let pixels = 43300.0
        XCTAssertEqual(DistanceConverter.pixelsToMeters(pixels), 10.0, accuracy: 0.001)
    }

    // MARK: - metersToKilometers

    func testMetersToKilometersZero() {
        XCTAssertEqual(DistanceConverter.metersToKilometers(0), 0)
    }

    func testMetersToKilometersKnownValue() {
        XCTAssertEqual(DistanceConverter.metersToKilometers(1000), 1.0, accuracy: 0.001)
    }

    func testMetersToKilometersFractional() {
        XCTAssertEqual(DistanceConverter.metersToKilometers(500), 0.5, accuracy: 0.001)
    }

    // MARK: - metersToFeet

    func testMetersToFeetZero() {
        XCTAssertEqual(DistanceConverter.metersToFeet(0), 0)
    }

    func testMetersToFeetOneMeter() {
        // 1 meter = 1 / 0.3048 feet ~ 3.28084 feet
        XCTAssertEqual(DistanceConverter.metersToFeet(1.0), 3.28084, accuracy: 0.001)
    }

    // MARK: - feetToMiles

    func testFeetToMilesZero() {
        XCTAssertEqual(DistanceConverter.feetToMiles(0), 0)
    }

    func testFeetToMilesOneMile() {
        XCTAssertEqual(DistanceConverter.feetToMiles(5280), 1.0, accuracy: 0.001)
    }

    // MARK: - formatDistance (metric)

    func testFormatDistanceMetricMeters() {
        // Small distance: should show meters
        let pixels = 4330.0 * 500 // 500 meters
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertEqual(result, "500.0 m")
    }

    func testFormatDistanceMetricKilometers() {
        // Large distance: should show kilometers
        let pixels = 4330.0 * 1500 // 1500 meters = 1.5 km
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertEqual(result, "1.50 km")
    }

    func testFormatDistanceMetricThreshold() {
        // Exactly 1000 meters should switch to km
        let pixels = 4330.0 * 1000
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertEqual(result, "1.00 km")
    }

    func testFormatDistanceMetricBelowThreshold() {
        // 999 meters stays in meters
        let pixels = 4330.0 * 999
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertTrue(result.hasSuffix(" m"))
    }

    func testFormatDistanceDefaultsToMetric() {
        let pixels = 4330.0 * 100
        let result = DistanceConverter.formatDistance(pixels)
        XCTAssertTrue(result.hasSuffix(" m"))
    }

    // MARK: - formatDistance (imperial)

    func testFormatDistanceImperialFeet() {
        // Small distance: should show feet
        let pixels = 4330.0 * 100 // 100 meters ~ 328 feet
        let result = DistanceConverter.formatDistance(pixels, unit: .imperial)
        XCTAssertTrue(result.hasSuffix(" ft"))
    }

    func testFormatDistanceImperialMiles() {
        // Large distance: should show miles
        let pixels = 4330.0 * 5000 // 5000 meters ~ 3.1 miles
        let result = DistanceConverter.formatDistance(pixels, unit: .imperial)
        XCTAssertTrue(result.hasSuffix(" mi"))
    }

    // MARK: - formatDistance zero

    func testFormatDistanceZero() {
        let result = DistanceConverter.formatDistance(0, unit: .metric)
        XCTAssertEqual(result, "0.0 m")
    }

    // MARK: - percentAroundEarth

    func testPercentAroundEarthZero() {
        XCTAssertEqual(DistanceConverter.percentAroundEarth(0), 0)
    }

    func testPercentAroundEarthKnownValue() {
        // Earth circumference = 40,075,000 meters
        // pixelsPerMeter = 4330
        let earthPixels = 40_075_000.0 * 4330.0
        XCTAssertEqual(DistanceConverter.percentAroundEarth(earthPixels), 100.0, accuracy: 0.001)
    }

    // MARK: - percentToMoon

    func testPercentToMoonZero() {
        XCTAssertEqual(DistanceConverter.percentToMoon(0), 0)
    }

    func testPercentToMoonKnownValue() {
        // Moon distance = 384,400,000 meters
        let moonPixels = 384_400_000.0 * 4330.0
        XCTAssertEqual(DistanceConverter.percentToMoon(moonPixels), 100.0, accuracy: 0.001)
    }

    // MARK: - formatEarthComparison

    func testFormatEarthComparisonContainsPercentSign() {
        let result = DistanceConverter.formatEarthComparison(4330.0 * 100)
        XCTAssertTrue(result.contains("%"))
        XCTAssertTrue(result.contains("around the world"))
    }

    // MARK: - formatMoonComparison

    func testFormatMoonComparisonContainsPercentSign() {
        let result = DistanceConverter.formatMoonComparison(4330.0 * 100)
        XCTAssertTrue(result.contains("%"))
        XCTAssertTrue(result.contains("to the moon"))
    }
}
