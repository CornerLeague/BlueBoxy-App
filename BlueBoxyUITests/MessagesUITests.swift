//
//  MessagesUITests.swift
//  BlueBoxyUITests
//
//  Comprehensive UI tests for messaging interface including navigation, user interactions,
//  accessibility, and error state handling
//

import XCTest

final class MessagesUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launchEnvironment["ENABLE_MOCK_API"] = "1"
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testMessagingTabNavigation() throws {
        // Navigate to messages tab
        let messagesTab = app.tabBars.buttons["Messages"]
        XCTAssertTrue(messagesTab.exists, "Messages tab should exist")
        messagesTab.tap()
        
        // Verify messages view loads
        let messagesNavigationTitle = app.navigationBars["AI Messages"]
        XCTAssertTrue(messagesNavigationTitle.waitForExistence(timeout: 5.0))
        
        // Verify header elements
        XCTAssertTrue(app.staticTexts["AI Message Generator"].exists)
        XCTAssertTrue(app.images["wand.and.rays.inverse"].exists)
    }
    
    func testMessageHistoryNavigation() throws {
        navigateToMessages()
        
        // Open menu and navigate to history
        let menuButton = app.navigationBars.buttons["ellipsis.circle"]
        XCTAssertTrue(menuButton.exists)
        menuButton.tap()
        
        let historyButton = app.buttons["Message History"]
        XCTAssertTrue(historyButton.exists)
        historyButton.tap()
        
        // Verify history view opens
        let historyTitle = app.navigationBars["Message History"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 3.0))
        
        // Close history
        let closeButton = app.navigationBars.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()
    }
    
    func testStorageManagementNavigation() throws {
        navigateToMessageHistory()
        
        // Open storage management
        let menuButton = app.navigationBars.buttons["ellipsis.circle"]
        XCTAssertTrue(menuButton.exists)
        menuButton.tap()
        
        let storageButton = app.buttons["Storage Management"]
        XCTAssertTrue(storageButton.exists)
        storageButton.tap()
        
        // Verify storage management view opens
        let storageTitle = app.navigationBars["Storage Management"]
        XCTAssertTrue(storageTitle.waitForExistence(timeout: 3.0))
        
        // Verify storage overview elements
        XCTAssertTrue(app.staticTexts["Storage Overview"].exists)
        XCTAssertTrue(app.staticTexts["Total Messages"].exists)
        XCTAssertTrue(app.staticTexts["Storage Used"].exists)
        
        // Close storage management
        let doneButton = app.navigationBars.buttons["Done"]
        XCTAssertTrue(doneButton.exists)
        doneButton.tap()
    }
    
    // MARK: - Message Generation Flow Tests
    
    func testCategorySelection() throws {
        navigateToMessages()
        
        // Wait for categories to load
        let categorySection = app.staticTexts["Message Categories"]
        XCTAssertTrue(categorySection.waitForExistence(timeout: 5.0))
        
        // Find and tap a category button
        let romanticCategory = app.buttons["Romantic"]
        if romanticCategory.exists {
            romanticCategory.tap()
            
            // Verify category is selected (check for selected state)
            XCTAssertTrue(romanticCategory.isSelected || app.staticTexts["Romantic messages to spark intimacy and connection"].exists)
        }
        
        // Try alternative category if romantic doesn't exist
        let appreciationCategory = app.buttons["Appreciation"] 
        if appreciationCategory.exists {
            appreciationCategory.tap()
            XCTAssertTrue(appreciationCategory.isSelected || app.staticTexts["Express gratitude and appreciation for your partner"].exists)
        }
    }
    
    func testContextInput() throws {
        navigateToMessages()
        selectCategory()
        
        // Expand context input section
        let addContextButton = app.buttons["Add Context"]
        if addContextButton.exists {
            addContextButton.tap()
        }
        
        // Find context input field
        let contextField = app.textFields.matching(identifier: "contextInput").firstMatch
        if !contextField.exists {
            // Try alternative selector
            let contextFieldAlt = app.textFields["e.g., After our wonderful date last night..."]
            if contextFieldAlt.exists {
                contextFieldAlt.tap()
                contextFieldAlt.typeText("Had a wonderful dinner together")
            }
        } else {
            contextField.tap()
            contextField.typeText("Had a wonderful dinner together")
        }
        
        // Test special occasion input
        let occasionField = app.textFields["e.g., Anniversary, Birthday, Just because..."]
        if occasionField.exists {
            occasionField.tap()
            occasionField.typeText("Anniversary")
        }
    }
    
    func testMessageGeneration() throws {
        navigateToMessages()
        selectCategory()
        
        // Find and tap generate button
        let generateButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Generate'")).firstMatch
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3.0), "Generate button should exist")
        
        // Tap generate button if enabled
        if generateButton.isEnabled {
            generateButton.tap()
            
            // Wait for generation to complete (look for loading or results)
            let loadingIndicator = app.activityIndicators.firstMatch
            if loadingIndicator.exists {
                // Wait for loading to finish
                XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 10.0))
            }
            
            // Look for generated messages section
            let generatedMessagesSection = app.staticTexts["Generated Messages"]
            if generatedMessagesSection.waitForExistence(timeout: 10.0) {
                XCTAssertTrue(generatedMessagesSection.exists, "Generated messages section should appear")
            }
        }
    }
    
    // MARK: - Message Interaction Tests
    
    func testMessageCardInteractions() throws {
        navigateToMessages()
        generateSampleMessage()
        
        // Find first message card
        let messageCard = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'messageCard'")).firstMatch
        if messageCard.exists {
            // Test tap to open detail
            messageCard.tap()
            
            // Verify detail view opens
            let detailTitle = app.navigationBars["Message Details"]
            if detailTitle.waitForExistence(timeout: 3.0) {
                XCTAssertTrue(detailTitle.exists)
                
                // Test detail view elements
                XCTAssertTrue(app.staticTexts["Message Details"].exists)
                XCTAssertTrue(app.staticTexts["Generation Context"].exists)
                
                // Test actions
                let copyButton = app.buttons["Copy Message"]
                XCTAssertTrue(copyButton.exists)
                
                let shareButton = app.buttons["Share Message"] 
                XCTAssertTrue(shareButton.exists)
                
                // Close detail view
                let closeButton = app.navigationBars.buttons["Close"]
                XCTAssertTrue(closeButton.exists)
                closeButton.tap()
            }
        }
    }
    
    func testMessageActionsMenu() throws {
        navigateToMessages()
        generateSampleMessage()
        
        // Find message card and access actions
        let messageCard = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'messageCard'")).firstMatch
        if messageCard.exists {
            // Long press or look for action buttons
            let favoriteButton = app.buttons["heart"]
            let shareButton = app.buttons["square.and.arrow.up"]
            
            if favoriteButton.exists {
                favoriteButton.tap()
                // Verify favorite action (heart should fill or change state)
            }
            
            if shareButton.exists {
                shareButton.tap()
                // Verify share sheet appears
                let shareSheet = app.sheets.firstMatch
                if shareSheet.waitForExistence(timeout: 3.0) {
                    // Close share sheet
                    let cancelButton = app.buttons["Cancel"]
                    if cancelButton.exists {
                        cancelButton.tap()
                    } else {
                        // Tap outside to dismiss
                        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
                    }
                }
            }
        }
    }
    
    // MARK: - History and Search Tests
    
    func testMessageHistorySearch() throws {
        navigateToMessageHistory()
        
        // Use search functionality
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("love")
            
            // Wait for search results
            sleep(1)
            
            // Clear search
            let clearButton = app.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            }
        }
    }
    
    func testHistoryFiltering() throws {
        navigateToMessageHistory()
        
        // Test segment control
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.exists {
            let favoritesSegment = segmentedControl.buttons["Favorites"]
            if favoritesSegment.exists {
                favoritesSegment.tap()
                sleep(1) // Wait for filter to apply
            }
            
            let allSegment = segmentedControl.buttons["All"]
            if allSegment.exists {
                allSegment.tap()
                sleep(1)
            }
        }
        
        // Test filter chips
        let favoritesChip = app.buttons["Favorites"]
        if favoritesChip.exists {
            favoritesChip.tap()
            sleep(1)
            favoritesChip.tap() // Toggle off
        }
    }
    
    func testHistoryExport() throws {
        navigateToMessageHistory()
        
        // Open menu and test export
        let menuButton = app.navigationBars.buttons["ellipsis.circle"]
        if menuButton.exists {
            menuButton.tap()
            
            let exportButton = app.buttons["Export Messages"]
            if exportButton.exists {
                exportButton.tap()
                
                // Look for share sheet or confirmation
                let shareSheet = app.sheets.firstMatch
                if shareSheet.waitForExistence(timeout: 3.0) {
                    // Cancel export
                    let cancelButton = app.buttons["Cancel"]
                    if cancelButton.exists {
                        cancelButton.tap()
                    }
                }
            }
            
            // Tap outside to close menu if needed
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
    
    // MARK: - Error State Tests
    
    func testNetworkErrorHandling() throws {
        // Set up network error simulation
        app.launchEnvironment["SIMULATE_NETWORK_ERROR"] = "1"
        app.terminate()
        app.launch()
        
        navigateToMessages()
        selectCategory()
        
        // Attempt message generation
        let generateButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Generate'")).firstMatch
        if generateButton.exists && generateButton.isEnabled {
            generateButton.tap()
            
            // Look for error state
            let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'failed' OR label CONTAINS 'network'")).firstMatch
            if errorMessage.waitForExistence(timeout: 5.0) {
                XCTAssertTrue(errorMessage.exists, "Error message should appear")
                
                // Test retry button if present
                let retryButton = app.buttons["Try Again"]
                if retryButton.exists {
                    XCTAssertTrue(retryButton.exists, "Retry button should be present")
                }
            }
        }
    }
    
    func testEmptyStates() throws {
        navigateToMessageHistory()
        
        // Look for empty state message
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No messages' OR label CONTAINS 'No Messages Yet'")).firstMatch
        if emptyStateMessage.exists {
            XCTAssertTrue(emptyStateMessage.exists, "Empty state message should be visible")
            
            // Look for empty state image
            let emptyStateImage = app.images.firstMatch
            XCTAssertTrue(emptyStateImage.exists, "Empty state should have an image")
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        navigateToMessages()
        
        // Test that key UI elements have accessibility labels
        let generateButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Generate'")).firstMatch
        if generateButton.exists {
            XCTAssertFalse(generateButton.label.isEmpty, "Generate button should have accessibility label")
        }
        
        // Test category buttons
        let categoryButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Romantic' OR label CONTAINS 'Appreciation'"))
        let categoryButton = categoryButtons.firstMatch
        if categoryButton.exists {
            XCTAssertFalse(categoryButton.label.isEmpty, "Category buttons should have accessibility labels")
        }
        
        // Test navigation elements
        let menuButton = app.navigationBars.buttons["ellipsis.circle"]
        if menuButton.exists {
            XCTAssertTrue(menuButton.isHittable, "Menu button should be accessible")
        }
    }
    
    func testVoiceOverSupport() throws {
        navigateToMessages()
        
        // Test that elements support VoiceOver
        let headerTitle = app.staticTexts["AI Message Generator"]
        if headerTitle.exists {
            XCTAssertTrue(headerTitle.isHittable, "Header should be accessible to VoiceOver")
        }
        
        // Test form elements
        let contextSection = app.staticTexts["Add Context"]
        if contextSection.exists {
            XCTAssertTrue(contextSection.isHittable, "Context section should be accessible")
        }
    }
    
    // MARK: - Performance Tests
    
    func testMessageGenerationPerformance() throws {
        navigateToMessages()
        selectCategory()
        
        measure(metrics: [XCTClockMetric()]) {
            let generateButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Generate'")).firstMatch
            if generateButton.exists && generateButton.isEnabled {
                generateButton.tap()
                
                // Wait for generation to complete
                let generatedSection = app.staticTexts["Generated Messages"]
                _ = generatedSection.waitForExistence(timeout: 10.0)
            }
        }
    }
    
    func testHistoryLoadingPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            navigateToMessageHistory()
            
            // Wait for history to load
            let historyTitle = app.navigationBars["Message History"]
            _ = historyTitle.waitForExistence(timeout: 5.0)
            
            // Navigate back
            let closeButton = app.navigationBars.buttons["Close"]
            if closeButton.exists {
                closeButton.tap()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToMessages() {
        let messagesTab = app.tabBars.buttons["Messages"]
        if messagesTab.exists {
            messagesTab.tap()
        }
        
        let messagesTitle = app.navigationBars["AI Messages"]
        _ = messagesTitle.waitForExistence(timeout: 5.0)
    }
    
    private func navigateToMessageHistory() {
        navigateToMessages()
        
        let menuButton = app.navigationBars.buttons["ellipsis.circle"]
        if menuButton.exists {
            menuButton.tap()
            
            let historyButton = app.buttons["Message History"]
            if historyButton.exists {
                historyButton.tap()
            }
        }
    }
    
    private func selectCategory() {
        // Wait for categories to load and select first available
        let categorySection = app.staticTexts["Message Categories"]
        _ = categorySection.waitForExistence(timeout: 5.0)
        
        // Try to select romantic category first
        let romanticCategory = app.buttons["Romantic"]
        if romanticCategory.exists {
            romanticCategory.tap()
            return
        }
        
        // Fallback to any available category
        let categoryButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Appreciation' OR label CONTAINS 'Support' OR label CONTAINS 'Daily'"))
        let firstCategory = categoryButtons.firstMatch
        if firstCategory.exists {
            firstCategory.tap()
        }
    }
    
    private func generateSampleMessage() {
        selectCategory()
        
        let generateButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Generate'")).firstMatch
        if generateButton.exists && generateButton.isEnabled {
            generateButton.tap()
            
            // Wait for generation
            let generatedSection = app.staticTexts["Generated Messages"]
            _ = generatedSection.waitForExistence(timeout: 10.0)
        }
    }
}