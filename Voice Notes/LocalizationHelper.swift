import Foundation
import SwiftUI

// MARK: - Localization Helper

extension String {
    /// Returns the localized version of this string
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized version of this string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Text Extension for Localized Strings

extension Text {
    /// Creates a Text view with a localized string
    init(localized key: String) {
        self.init(NSLocalizedString(key, comment: ""))
    }
    
    /// Creates a Text view with a localized string and format arguments
    init(localized key: String, arguments: CVarArg...) {
        let localizedString = String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
        self.init(localizedString)
    }
}

// MARK: - Localization Keys

struct L10n {
    // Tab Bar
    struct Tab {
        static let home = "tab.home"
        static let recordings = "tab.recordings"
        static let documents = "tab.documents"
        static let settings = "tab.settings"
    }
    
    // Home View
    struct Home {
        static let readyToRecord = "home.ready_to_record"
        static let tapToStart = "home.tap_to_start"
        static let recording = "home.recording"
        static let recordingPaused = "home.recording_paused"
        static let recentRecordings = "home.recent_recordings"
        static let viewAll = "home.view_all"
        static let recordingSettings = "home.recording_settings"
        static let noRecordingsMessage = "home.no_recordings_message"
    }
    
    // Recording
    struct Recording {
        static let newRecording = "recording.new_recording"
        static let transcribing = "recording.transcribing"
        static let summarizing = "recording.summarizing"
        static let processingComplete = "recording.processing_complete"
        static let failed = "recording.failed"
        static let tapToView = "recording.tap_to_view"
        static let details = "recording.details"
        static let delete = "recording.delete"
        static let done = "recording.done"
        static let share = "recording.share"
        static let edit = "recording.edit"
        static let play = "recording.play"
        static let pause = "recording.pause"
        static let retry = "recording.retry"
        static let transcript = "recording.transcript"
        static let summary = "recording.summary"
        static let actionItems = "recording.action_items"
        static let tags = "recording.tags"
        static let addTag = "recording.add_tag"
        static let duration = "recording.duration"
        static let date = "recording.date"
        static let fileSize = "recording.file_size"
    }
    
    // Alert Messages
    struct Alert {
        static let deleteRecording = "alert.delete_recording"
        static let deleteRecordingMessage = "alert.delete_recording_message"
        static let delete = "alert.delete"
        static let cancel = "alert.cancel"
    }
    
    // Lists/Documents
    struct Lists {
        static let title = "lists.title"
        static let createFirst = "lists.create_first"
        static let organizeNotes = "lists.organize_notes"
        static let noLists = "lists.no_lists"
        static let createTodoShopping = "lists.create_todo_shopping"
    }
    
    // Document Types
    struct Document {
        static let todo = "document.todo"
        static let shopping = "document.shopping"
        static let ideas = "document.ideas"
        static let meeting = "document.meeting"
        static let tasks = "document.tasks"
        static let newList = "document.new_list"
        static let listTitle = "document.list_title"
        static let listType = "document.list_type"
        static let create = "document.create"
        static let save = "document.save"
        static let addNewItem = "document.add_new_item"
        static let noItems = "document.no_items"
        static let addItemsOrSave = "document.add_items_or_save"
        static let completed = "document.completed"
        static let add = "document.add"
    }
    
    // Filter Options
    struct Filter {
        static let all = "filter.all"
        static let open = "filter.open"
        static let done = "filter.done"
    }
    
    // Settings
    struct Settings {
        static let title = "settings.title"
        static let aiProvider = "settings.ai_provider"
        static let aiProviderSettings = "settings.ai_provider_settings"
        static let configureProviders = "settings.configure_providers"
        static let usageAnalytics = "settings.usage_analytics"
        static let viewPerformance = "settings.view_performance"
        static let manageTags = "settings.manage_tags"
        static let organizeRenameMerge = "settings.organize_rename_merge"
        static let summarySettings = "settings.summary_settings"
        static let aiSummaryMode = "settings.ai_summary_mode"
        static let summaryLength = "settings.summary_length"
        static let autoDetectMode = "settings.auto_detect_mode"
        static let privacyData = "settings.privacy_data"
        static let privacyPolicy = "settings.privacy_policy"
        static let dataUsage = "settings.data_usage"
        static let appInfo = "settings.app_info"
        static let version = "settings.version"
        static let build = "settings.build"
        static let support = "settings.support"
    }
    
    // Actions
    struct Action {
        static let saveToList = "action.save_to_list"
        static let saveAll = "action.save_all"
        static let saveSelected = "action.save_selected"
        static let share = "action.share"
        static let copy = "action.copy"
        static let delete = "action.delete"
        static let edit = "action.edit"
        static let rename = "action.rename"
        static let merge = "action.merge"
    }
    
    // Progress and Status
    struct Progress {
        static let transcribing = "progress.transcribing"
        static let summarizing = "progress.summarizing"
    }
    
    struct Status {
        static let processing = "status.processing"
        static let completed = "status.completed"
        static let failed = "status.failed"
    }
    
    // Errors
    struct Error {
        static let transcriptionFailed = "error.transcription_failed"
        static let summarizationFailed = "error.summarization_failed"
        static let apiKeyMissing = "error.api_key_missing"
        static let networkError = "error.network_error"
        static let audioPlaybackFailed = "error.audio_playback_failed"
        static let recordingNotFound = "error.recording_not_found"
    }
    
    // Toast Messages
    struct Toast {
        static let addedItems = "toast.added_items"
        static let undo = "toast.undo"
        static let open = "toast.open"
    }
    
    // Tour
    struct Tour {
        static let welcome = "tour.welcome"
        static let recordVoiceNotes = "tour.record_voice_notes"
        static let aiSummaries = "tour.ai_summaries"
        static let organizeLists = "tour.organize_lists"
        static let getStarted = "tour.get_started"
        static let next = "tour.next"
        static let skip = "tour.skip"
        static let done = "tour.done"
    }
    
    // Tags
    struct Tags {
        static let manage = "tags.manage"
        static let add = "tags.add"
        static let noTags = "tags.no_tags"
        static let willAppear = "tags.will_appear"
        static let rename = "tags.rename"
        static let delete = "tags.delete"
        static let merge = "tags.merge"
        static let newName = "tags.new_name"
    }
    
    // Miscellaneous
    struct Misc {
        static let items = "misc.items"
        static let item = "misc.item"
        static let minutes = "misc.minutes"
        static let seconds = "misc.seconds"
        static let ago = "misc.ago"
        static let justNow = "misc.just_now"
        static let loading = "misc.loading"
        static let search = "misc.search"
        static let close = "misc.close"
        static let `continue` = "misc.continue"
    }
}