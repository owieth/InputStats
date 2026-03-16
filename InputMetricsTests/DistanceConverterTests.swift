import XCTest
@testable import InputMetrics

final class DistanceConverterTests: XCTestCase {

    private var ppm: Double!

    override func setUp() {
        ppm = DistanceConverter.currentPixelsPerMeter
    }

    // MARK: - pixelsToMeters

    func testPixelsToMetersZero() {
        XCTAssertEqual(DistanceConverter.pixelsToMeters(0), 0)
    }

    func testPixelsToMetersKnownValue() {
        XCTAssertEqual(DistanceConverter.pixelsToMeters(ppm), 1.0, accuracy: 0.001)
    }

    func testPixelsToMetersLargeValue() {
        let pixels = ppm * 10
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
        let pixels = ppm * 500
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertEqual(result, "500.0 m")
    }

    func testFormatDistanceMetricKilometers() {
        let pixels = ppm * 1500
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertEqual(result, "1.50 km")
    }

    func testFormatDistanceMetricThreshold() {
        let pixels = ppm * 1000
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertEqual(result, "1.00 km")
    }

    func testFormatDistanceMetricBelowThreshold() {
        let pixels = ppm * 999
        let result = DistanceConverter.formatDistance(pixels, unit: .metric)
        XCTAssertTrue(result.hasSuffix(" m"))
    }

    func testFormatDistanceDefaultsToMetric() {
        let pixels = ppm * 100
        let result = DistanceConverter.formatDistance(pixels)
        XCTAssertTrue(result.hasSuffix(" m"))
    }

    // MARK: - formatDistance (imperial)

    func testFormatDistanceImperialFeet() {
        let pixels = ppm * 100
        let result = DistanceConverter.formatDistance(pixels, unit: .imperial)
        XCTAssertTrue(result.hasSuffix(" ft"))
    }

    func testFormatDistanceImperialMiles() {
        let pixels = ppm * 5000
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
        let earthPixels = Constants.earthCircumferenceMeters * ppm
        XCTAssertEqual(DistanceConverter.percentAroundEarth(earthPixels), 100.0, accuracy: 0.001)
    }

    // MARK: - percentToMoon

    func testPercentToMoonZero() {
        XCTAssertEqual(DistanceConverter.percentToMoon(0), 0)
    }

    func testPercentToMoonKnownValue() {
        let moonPixels = Constants.moonDistanceMeters * ppm
        XCTAssertEqual(DistanceConverter.percentToMoon(moonPixels), 100.0, accuracy: 0.001)
    }

    // MARK: - formatEarthComparison

    func testFormatEarthComparisonContainsPercentSign() {
        let result = DistanceConverter.formatEarthComparison(ppm * 100)
        XCTAssertTrue(result.contains("%"))
        XCTAssertTrue(result.contains("around the world"))
    }

    // MARK: - formatMoonComparison

    func testFormatMoonComparisonContainsPercentSign() {
        let result = DistanceConverter.formatMoonComparison(ppm * 100)
        XCTAssertTrue(result.contains("%"))
        XCTAssertTrue(result.contains("to the moon"))
    }
}
