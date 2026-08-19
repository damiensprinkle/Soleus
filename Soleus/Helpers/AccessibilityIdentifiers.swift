import Foundation

enum AccessibilityID {
    // MARK: - Tabs
    static let tabWorkout = "tab_workout"
    static let tabDashboard = "tab_dashboard"
    static let tabSettings = "tab_settings"

    // MARK: - Workout Main View Nav Bar
    static let navReorderButton = "nav_reorder_button"
    static let navImportButton = "nav_import_button"
    static let navScheduleButton = "nav_schedule_button"
    static let navHistoryButton = "nav_history_button"
    static let navAddWorkoutButton = "nav_add_workout_button"

    // MARK: - Workout Main View Empty State
    static let emptyStateTitle = "empty_state_title"
    static let emptyStateCreateButton = "empty_state_create_button"

    // MARK: - Active Session Banner
    static let activeSessionBanner = "active_session_banner"

    // MARK: - Dashboard
    static let dashboardCustomizeButton = "dashboard_customize_button"
    static let dashboardCustomizeDoneButton = "dashboard_customize_done_button"
    static let dashboardResumeBanner = "dashboard_resume_banner"
    static let dashboardLastWorkoutCard = "dashboard_last_workout_card"
    static let dashboardTodaysWorkoutCard = "dashboard_todays_workout_card"
    static let dashboardScheduleSetupButton = "dashboard_schedule_setup_button"
    // Per-widget toggle identifiers are generated dynamically in DashboardCustomizeView:
    //   "widget_toggle_\(widget.rawValue)"

    // MARK: - Weekly Schedule
    static let scheduleBackButton = "schedule_back_button"
    // Per-day add buttons are generated dynamically in WeeklyScheduleView:
    //   "schedule_add_day_\(weekday)"

    // MARK: - Add/Edit Workout View
    static let addWorkoutCancelButton = "add_workout_cancel_button"
    static let addWorkoutSaveButton = "add_workout_save_button"
    static let addWorkoutTitleField = "add_workout_title_field"
    static let addWorkoutAddExerciseButton = "add_workout_add_exercise_button"
    static let exerciseCard = "exercise_card"

    // MARK: - Add Exercise Dialog
    static let exerciseNameField = "exercise_name_field"
    static let exerciseTrackByPicker = "exercise_track_by_picker"
    static let exerciseMeasureWithPicker = "exercise_measure_with_picker"
    static let exerciseDialogCancelButton = "exercise_dialog_cancel_button"
    static let exerciseDialogAddButton = "exercise_dialog_add_button"

    // MARK: - History View
    static let historyEmptyStateText = "history_empty_state_text"
    static let historyModeList = "history_mode_list"
    static let historyModeCalendar = "history_mode_calendar"
    static let historyModeProgress = "history_mode_progress"
    static let historyCalendarPreviousMonth = "history_calendar_previous_month"
    static let historyCalendarNextMonth = "history_calendar_next_month"
    static let historyCalendarMonthLabel = "history_calendar_month_label"
    static let historyProgressSearchField = "history_progress_search_field"

    // MARK: - Exercise Picker
    static let exercisePickerSearchField = "exercise_picker_search_field"
    static let exercisePickerCloseButton = "exercise_picker_close_button"
    static let exercisePickerCreateCustomButton = "exercise_picker_create_custom_button"

    // MARK: - My Exercises
    static let myExercisesAddButton = "my_exercises_add_button"
    static let myExercisesSortButton = "my_exercises_sort_button"
    static let myExercisesNameField = "my_exercises_name_field"
    static let myExercisesSaveButton = "my_exercises_save_button"

    // MARK: - Settings View
    static let settingsMyExercisesButton = "settings_my_exercises_button"
    static let settingsHealthKitButton = "settings_health_kit_button"
    static let healthKitToggle = "health_kit_toggle"
    static let settingsWeightPicker = "settings_weight_picker"
    static let settingsDistancePicker = "settings_distance_picker"
    static let settingsImportButton = "settings_import_button"
    static let settingsRestTimerToggle = "settings_rest_timer_toggle"
    static let settingsHelpButton = "settings_help_button"
    static let settingsPrivacyButton = "settings_privacy_button"
    static let settingsContactUsButton = "settings_contact_us_button"

    // MARK: - Contact Us View
    static let contactUsBugReportButton = "contact_us_bug_report_button"
    static let contactUsFeatureRequestButton = "contact_us_feature_request_button"
    static let contactUsAttachLogsToggle = "contact_us_attach_logs_toggle"

    // MARK: - Import Preview
    static let importPreviewNameField = "import_preview_name_field"
    static let importPreviewCancelButton = "import_preview_cancel_button"
    static let importPreviewImportButton = "import_preview_import_button"

    // MARK: - Template Picker
    static let templatePickerButton = "template_picker_button"
    static let templatePickerCancelButton = "template_picker_cancel_button"
    static let templatePickerRow = "template_picker_row"

    // MARK: - Active Workout
    static let startWorkoutButton = "start_workout_button"
    static let activeEditModeButton = "active_edit_mode_button"
    static let activeAddExerciseButton = "active_add_exercise_button"
    static let keyboardDoneButton = "keyboard_done_button"
    // Per-set identifiers are generated dynamically in ExerciseRowActive:
    //   "reps_set_\(setIndex)", "weight_set_\(setIndex)", "complete_set_\(setIndex)"
    // Per-exercise identifiers are generated dynamically in ActiveWorkoutView:
    //   "note_button_\(index)", "exercise_menu_\(index)", "add_set_button_\(index)", "notes_field_\(index)"
}
