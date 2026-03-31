import XCTest

final class OpenLuminaUITests: XCTestCase {
    @MainActor
    func testLaunchShowsEmptyState() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["No study open"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSyntheticFolderScenarioLoadsStudyAndNavigatesImages() {
        let app = XCUIApplication()
        app.launchEnvironment["OPEN_LUMINA_UI_TEST_SCENARIO"] = "folder"
        app.launch()

        app.buttons["open-folder-button"].click()

        XCTAssertTrue(app.staticTexts["FolderStudy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["next-image-button"].exists)
        XCTAssertTrue(app.buttons["export-image-button"].isEnabled)
        app.buttons["next-image-button"].click()
        XCTAssertTrue(app.otherElements["dicom-image-view"].exists)
    }

    @MainActor
    func testSyntheticISOScenarioLoadsViaMockImporter() {
        let app = XCUIApplication()
        app.launchEnvironment["OPEN_LUMINA_UI_TEST_SCENARIO"] = "iso"
        app.launch()

        app.buttons["open-iso-button"].click()

        XCTAssertTrue(app.staticTexts["MountedISO"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["dicom-image-view"].waitForExistence(timeout: 5))
    }
}
