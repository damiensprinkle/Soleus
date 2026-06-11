# Soleus Unit Tests

## Overview

This directory contains unit tests for the Soleus workout tracking app. Tests use mock implementations to verify business logic without requiring CoreData or UI.

---

## Running Tests

### In Xcode:
1. Open Soleus.xcodeproj
2. Press `Cmd + U` to run all tests
3. Or navigate to Test Navigator (Cmd + 6) and click the play button

### From Command Line:
```bash
# Run all tests
xcodebuild test -scheme Soleus -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

---

## Mock Objects

### MockWorkoutManager
A complete mock implementation of the `WorkoutManaging` protocol that:
- Stores test data in memory (no CoreData required)
- Tracks method calls for verification
- Returns predictable test data
- Supports all WorkoutManaging protocol methods
- Avoids CoreData complexity by using simple data structures

**Key Features:**
- `storedWorkoutData` - In-memory workout storage using tuples
- `storedHistory` - In-memory history storage
- `addWorkoutDetailCalled` - Verification flag
- `deleteWorkoutCalled` - Verification flag
- `updateWorkoutDetailsCalled` - Verification flag
- `lastDeletedWorkoutId` - Tracks last deletion
- `lastUpdatedWorkoutId` - Tracks last update

**Usage Example:**
```swift
func testExample() {
    // Given
    let mockManager = MockWorkoutManager()
    let viewModel = WorkoutTrackerViewModel(workoutManager: mockManager)

    // When
    viewModel.deleteWorkout(someId)

    // Then
    XCTAssertTrue(mockManager.deleteWorkoutCalled)
    XCTAssertEqual(mockManager.lastDeletedWorkoutId, someId)
}
```

---

## Adding New Tests

### 1. Test File Structure
```swift
import XCTest
@testable import Soleus

final class YourTests: XCTestCase {
    var sut: SystemUnderTest!
    var mockManager: MockWorkoutManager!

    override func setUp() {
        super.setUp()
        mockManager = MockWorkoutManager()
        sut = SystemUnderTest(workoutManager: mockManager)
    }

    override func tearDown() {
        sut = nil
        mockManager = nil
        super.tearDown()
    }

    func testYourFeature() {
        // Given

        // When

        // Then
    }
}
```

### 2. Test Naming Convention
Use descriptive names following the pattern:
```
test[MethodName]_[Scenario]_[ExpectedResult]
```

Examples:
- `testSaveWorkout_WithEmptyTitle_ReturnsError`
- `testLoadWorkouts_LoadsWorkoutsFromManager`
- `testDeleteExercise_RemovesExerciseFromList`

### 3. Use Given-When-Then Pattern
```swift
func testExample() {
    // Given - Setup test data and preconditions
    let expectedValue = 42

    // When - Execute the code being tested
    let result = sut.someMethod()

    // Then - Verify the results
    XCTAssertEqual(result, expectedValue)
}
```
