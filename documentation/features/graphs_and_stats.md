# Visualisations - Graphs, Statistics, and Analysis

This document covers the graphs and statistics features of the Impactive Sleep Tracker App.

## Overview

The app provides several visualization tools to help users understand their sleep patterns, efficiency, and correlations with daily habits. These features include various chart types and interactive displays accessible from the main app landing page.

This set of visualisations allows users to get data-driven insights about their sleep health and daily habits that can be shared with healthcare professionals. 

> [!TIP]
> For more advanced analysis, user data can be exported through the [log service](/documentation/features/data_management.md).

- Visualizations
  - [Sleep Statistics (Bar Chart)](#sleep-statistics-bar-chart)
  - [Sleep Progress Graph (Diary)](#sleep-progress-graph-diary)
  - [Circadian Drift (Mid-Sleep Point Trend)](#circadian-drift-mid-sleep-point-trend)
  - [Sleep Consistency (Heatmap)](#sleep-consistency-heatmap)
  - [Sleep Efficiency](#sleep-efficiency)
  - [Habits vs. Sleep Latency (Correlation Analysis)](#habits-vs-sleep-latency-correlation-analysis)
- Implementation
  - [Technical Implementation](#technical-implementation)
  - [Data Sources](#data-sources)


## Sleep Statistics (Bar Chart)

A basic bar chart view showing recent sleep performance:

- **Weekly Bar Chart**: Displays sleep duration for the past 7 days
- **Interactive Tooltips**: Tap and hold bars to see the exact sleep duration (e.g., "08h30m")
- **Day Labels**: X-axis shows day of the week
- **Hour Scale**: Y-axis shows sleep hours for that day

This provides a quick overview of recent sleep consistency and helps spot short-term trends in sleep duration.

## Sleep Progress Graph (Diary)

The Sleep Progress Graph provides a detailed timeline view of sleep patterns over multiple days, mimicking a paper sleep diary. Key features include:

- **Horizontal Timeline**: Displays a 24-hour timeline (midnight to midnight)
- **Sleep Bars**: Colored bars showing actual sleep periods (indigo shading) during the day
- **Bed Time Indicators**: Vertical teal lines marking when the user went to bed
- **Activity Symbols**: Interactive markers for:
  - **C** - Caffeine intake (brown)
  - **A** - Alcohol consumption (red)
  - **M** - Medication (green)
  - **E** - Exercise (orange)
- **Date Navigation**: Left column shows dates with day of week and day type icon
- **Multi-Day Loading**: Loads up to 30 days of data

This graph helps identify patterns in sleep timing, duration, and how daily activities affect sleep quality in a familiar format similar to a paper sleep diary.

## Circadian Drift (Mid-Sleep Point Trend)

Tracks long-term changes in sleep timing:

- **Trend Line**: Connects mid-sleep points (middle of longest sleep period each night) over time
- **Time Scale**: Y-axis shows 24-hour clock format
- **Date Labels**: X-axis shows day/month format
- **Scrollable View**: Horizontal scrolling for up to 30 days
- **Average Display**: Shows calculated average mid-sleep time in a stats box
- **Drift Indication**: Trending upward means sleep is shifting later over time

This helps identify circadian rhythm shifts and jet lag effects.

## Sleep Consistency (Heatmap)

A long-term overview of sleep duration over the past year using a heatmap (similar in format to a GitHub contributions heatmap):

- **Calendar Grid**: 7x52 grid showing each day of the past year
- **Color Intensity**: Sleep hours mapped to thermal gradient:
  - Light blue/cyan: Low sleep (< 3 hours)
  - Green/yellow: Medium sleep (3-6 hours)
  - Orange/red: High sleep (> 6 hours)
  - Grey: No data
- **Month Labels**: Horizontal headers showing month abbreviations
- **Day Labels**: Vertical labels for Mon, Wed, Fri, Sun
- **Interactive**: Tap any cell to see exact sleep duration for that date
- **Scrollable**: Horizontal scrolling starts from most recent data

This provides a bird's-eye view of sleep duration consistency over long periods.

## Sleep Efficiency

Analyzes sleep quality by comparing time spent in bed versus actual sleep time:

- **Stacked Bars**: Each bar represents one day, with efficiency above each bar as a percentage
  - Grey portion: Total time in bed (awake time)
  - Colored portion: Actual sleep time
- **Efficiency Coloring**:
  - Green: > 90% efficiency (excellent)
  - Light green: 80-90% (good)
  - Orange: 70-80% (fair)
  - Red: < 70% (poor)
- **Date Labels**: Bottom labels show day/month format
- **Scrollable**: Horizontal scrolling for 30-day view

This helps identify nights with poor sleep efficiency and potential sleep disorders.

## Habits vs. Sleep Latency (Correlation Analysis)

Explores how daily habits affect time to fall asleep:

- **Scatter Plot**: Each point represents a habit occurrence and its impact on sleep latency
- **Habit Types**:
  - Brown circles: Caffeine (coffee, tea, cola, energy drinks)
  - Purple circles: Alcohol (wine, beer, etc.)
  - Orange circles: Exercise
- **Axes**:
  - X-axis: Time of habit consumption (6:00 to 24:00)
  - Y-axis: Minutes to fall asleep (0-120 minutes)
- **Data Window**: Analyzes past 60 days of data
- **Cross-Day Analysis**: Considers habits from previous day that might affect sleep

This may help users understand which habits most significantly delay sleep onset and optimize their evening routines.

## Technical Implementation

All graphs are built using Flutter's CustomPaint for high-performance rendering:

- **Dynamic Scaling**: Graphs adapt to screen size and data ranges
- **Dark Mode Support**: Automatic color adjustments for light/dark themes
- **Efficient Data Loading**: Loads only necessary data periods to maintain performance
- **Interactive Elements**: Touch gestures for data label tooltips

## Data Sources

Graphs pull data from the app's log service, including:

- Sleep entries (bed time, asleep time, wake time, awake duration)
- Substance logs (caffeine, alcohol, medication)
- Exercise logs (timing and duration)
- Day type categories for contextual markers
