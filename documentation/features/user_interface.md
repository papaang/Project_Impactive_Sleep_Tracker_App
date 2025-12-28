# User Interface

This document covers the main user interface aspects of the Impactive Sleep Tracker.

## Home Screen

The home screen is the main entry point of the app and provides an overview of the user's current sleep status and quick access to key features.

### Layout and Components

- **App Bar**: Displays "Home" as the title with a settings icon in the top-right corner for quick access to settings.
- **Navigation Drawer**: Accessible by swiping from the left edge or tapping the hamburger menu icon. Contains links to:
  - Home
  - Today's Events
  - Statistics
  - Past Entries Calendar
  - Settings

- **Status Card**: Shows the current sleep status message (e.g., "Welcome! Tap 'Going to sleep' to start." or sleep duration summary). Includes a visual sleep clock when sleep data is available, displaying past sleep sessions as arcs and current sleep progress.

> [!TIP]
> Click on the clock face visualisation to go to [today's events screen](/documentation/features/events.md)

- **Sleep Controls**: Two large buttons for sleep management:
  - "Wake Up" and "Sleep" buttons when not in bed
  - "Got Out of Bed" button when awake in bed

- **Day Type Selector**: A customizable selector to categorize the type of day (e.g., Work Day, Rest Day). Tapping opens a dialog to select or add new day types, with an option to manage categories.

- **Activities and Visualisations Grid**: A 2-column grid of buttons for various app functions:
  - Medication: Log medication intake
  - +1 Caffeine: Quick-add one cup of caffeine (long-press for full caffeine/alcohol screen)
  - Exercise: Log physical activity
  - Notes: Add daily notes
  - Statistics: View sleep statistics
  - Sleep Graph: Visualize sleep patterns over time
  - Heatmap: View sleep data in calendar heatmap format
  - Circadian Drift: Analyze circadian rhythm shifts
  - Correlations: Explore relationships between sleep and activities
  - Efficiency: View sleep efficiency metrics
  - History: Access past entries calendar
  - Settings: App settings

For more information on activities [click here](/documentation/features/events.md#daily-activity-logging).\
For more information on visualisations [click here](/documentation/features/graphs_and_stats.md).

## Navigation to Events Screen

The [Events screen](/documentation/features/events.md) allows detailed logging and editing of daily activities for a specific date.

### Accessing the Events Screen

- From the home screen navigation drawer: Tap "Today's Events" to view/edit events for the current day.
- The Events screen displays the selected date in the app bar and provides sections for:
  - Sleep Sessions: List of logged sleep periods with edit/delete options
  - Day Type: Selector for categorizing the day
  - Activity Buttons: Quick access to Medication, Caffeine & Alcohol, Exercise, and Notes screens

## Settings Screen

### Accessing the Settings Screen

- From the home screen app bar: Tap the settings icon (gear) in the top-right corner, or
- From the navigation drawer: Tap "Settings".

### Settings Screen Contents

- **Dark Mode Toggle**: Switch between light and dark themes.
- **Manage Categories**: Button to access the [category management screen](/documentation/features/events.md#categories) for customizing day types, sleep locations, etc.
- **Export Data as CSV**: Button to [export all logged data](/documentation/features/data_management.md#data-export) as a CSV file for external analysis.
- **Clear All Saved Data**: Destructive action button to permanently delete all app data (with confirmation dialog).
- **App Info**: Version number and link to source code.
