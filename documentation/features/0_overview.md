# Overview

The Impactive Sleep Tracker App is a tool designed to help users monitor and improve their sleep patterns. Developed as part of Project Impactive, this Flutter-based application provides detailed tracking of sleep cycles, daily activities, and their correlations to sleep quality.

## Key Capabilities

- **Comprehensive Sleep Tracking**: Record bed time, asleep time, wake time, and rise time to monitor sleep duration and patterns.
- **Activity Logging**: Log daily activities such as caffeine and alcohol intake, exercise, medication, and personal notes.
- **Data Analysis**: Visualize sleep data through graphs, heatmaps, and statistical analysis to identify trends and correlations.
- **Data Management**: Import and export sleep data for further analysis or backup.
- **User-Friendly Interface**: Intuitive design for easy navigation and data entry.

## Target Users

This app is particularly beneficial for individuals with circadian rhythm disorders. It serves as a digital alternative to traditional paper sleep diaries, offering enhanced analysis capabilities.

## Technical Details

Built with Flutter for potential cross-platform compatibility, but primarily tested on Android devices. The app supports data persistence and provides export functionality for external analysis.

## How it could be improved
- Proper handling of time zone changes.
- Implement automatic backups of app data with Google Drive, OneDrive, etc. accounts.
- Ability to edit sleep entries and drag-and-drop events from the classic sleep diary visualisation.
- Ability to export the generated sleep diary as a multi-page PDF.
- Time range adjustability for all visualisations
- More appearance settings – ability to customise font style, font size, and more color themes.

## Documentation Contents

1. **[User Interface](1_user_interface.md)**
   - [Home Screen](1_user_interface.md#home-screen)
   - [Navigation to Events Screen](1_user_interface.md#navigation-to-events-screen)
   - [Settings Screen](1_user_interface.md#settings-screen)

2. **[Sleep Tracking and Editing](2_sleep_tracking_and_editing.md)**
   - [Sleep Tracking](2_sleep_tracking_and_editing.md#sleep-tracking)
   - [Editing Past Entries](2_sleep_tracking_and_editing.md#editing-past-entries)
   - [Data Validation](2_sleep_tracking_and_editing.md#data-validation)

3. **[Daily Activity Logging](3_events.md)**
   - [Entry Types](3_events.md#entry-types)
   - [Notification Service](3_events.md#notification-service)
   - [Categories](3_events.md#categories)

4. **[Visualisations - Graphs, Statistics, and Analysis](4_graphs_and_stats.md)**
   - [Overview](4_graphs_and_stats.md#overview)
   - [Sleep Statistics (Bar Chart)](4_graphs_and_stats.md#sleep-statistics-bar-chart)
   - [Sleep Progress Graph (Diary)](4_graphs_and_stats.md#sleep-progress-graph-diary)
   - [Circadian Drift (Mid-Sleep Point Trend)](4_graphs_and_stats.md#circadian-drift-mid-sleep-point-trend)
   - [Sleep Consistency (Heatmap)](4_graphs_and_stats.md#sleep-consistency-heatmap)
   - [Sleep Efficiency](4_graphs_and_stats.md#sleep-efficiency)
   - [Habits vs. Sleep Latency (Correlation Analysis)](4_graphs_and_stats.md#habits-vs-sleep-latency-correlation-analysis)

5. **[Data Management](5_data_management.md)**
   - [Data Export](5_data_management.md#data-export)
   - [Data Import](5_data_management.md#data-import)
   - [Privacy and Security](5_data_management.md#privacy-and-security)
   - [Data Structure](5_data_management.md#data-structure)
