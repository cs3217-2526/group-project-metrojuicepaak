import XCTest

final class SamplerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()

        app.launchArguments.append("--uitesting")
        
        // Boot the app
        app.launch()
    }

    func testRecordingEndToEndFlow() throws {
        let editToggle = app.switches["EditModeToggle"]
        if editToggle.exists, (editToggle.value as? String) == "1" {
            editToggle.tap()
        }
        
        let pad0 = app.buttons["SamplerPad_0"]
        XCTAssertTrue(pad0.waitForExistence(timeout: 5.0), "Pad 0 must be rendered on the screen")
        
        pad0.press(forDuration: 2.0)
        
        if editToggle.exists {
            editToggle.tap()
        } else {
            let editButton = app.buttons["EditModeButton"]
            if editButton.exists { editButton.tap() }
        }
        
        pad0.tap()
        
        let isEditorVisible = app.staticTexts["Edit Sample"].waitForExistence(timeout: 3.0)
        XCTAssertTrue(isEditorVisible, "After recording to an empty pad, tapping it in Edit Mode must open the Waveform Editor, proving the mock audio was successfully assigned.")
    }
        
    func testEditModeNavigation() throws {
        let editToggle = app.switches["EditModeToggle"]
        if editToggle.waitForExistence(timeout: 2.0) {
            editToggle.tap()
        } else {
            let editButton = app.buttons["EditModeButton"]
            if editButton.exists {
                editButton.tap()
            }
        }
        
        let pad1 = app.buttons["SamplerPad_1"]
        XCTAssertTrue(pad1.waitForExistence(timeout: 2.0), "Pad 1 must exist")
        pad1.tap()
        
        let isPickerVisible = app.staticTexts["Sample Picker"].waitForExistence(timeout: 2.0)
        
        XCTAssertTrue(isPickerVisible, "Tapping a pad without audio assignment in Edit Mode should open the Sample Picker")
    }
    
    func testNormalModePlayback() throws {
        let editToggle = app.switches["EditModeToggle"]
        if editToggle.exists, (editToggle.value as? String) == "1" {
            editToggle.tap()
        }
        
        let pad2 = app.buttons["SamplerPad_2"]
        XCTAssertTrue(pad2.waitForExistence(timeout: 2.0), "Pad 2 must exist")
        pad2.tap()
        
        let isEditorVisible = app.staticTexts["Edit Sample"].exists
        
        let isPickerVisible = app.staticTexts["Sample Picker"].exists
        
        XCTAssertFalse(isEditorVisible, "Tapping a pad in Normal mode should NOT open the editor")
        XCTAssertFalse(isPickerVisible, "Tapping a pad in Normal mode should NOT open the picker")
    }
}
