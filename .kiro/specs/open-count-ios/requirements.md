# Requirements Document

## Introduction

OpenCount is a free, open-source, native iOS application for AI-powered object counting in photos and live camera feeds. It combines zero-shot on-device AI detection (no templates required), manual tap-to-count, multi-class counting, region-of-interest filtering, live camera counting, batch processing, and rich export capabilities. OpenCount is 100% free with no paywalls, no subscriptions, and no license requirements — surpassing CountThings from Photos (paid AI counting, closed source) and ZapCount (web-only, no offline support, no export).

## Glossary

- **App**: The OpenCount iOS application
- **Session**: A counting session containing one or more source images or a video, a set of Object_Types, and all counting results
- **Object_Type**: A user-defined category of object to count within a Session (e.g., "person", "car", "tree"), identified by a name, color, and icon
- **Count_Marker**: A visual point placed on an image (manually by the user or converted from an AI detection) representing one counted instance of an Object_Type
- **AI_Detection**: An object detection result produced by the on-device CoreML/Vision pipeline, consisting of a bounding box, class label, and Confidence_Score
- **Confidence_Score**: A floating-point value in the range [0.0, 1.0] representing the AI model's certainty for a given AI_Detection
- **Region**: A user-drawn geometric area (rectangle, ellipse, or freehand polygon) on an image that restricts counting to objects within its boundary
- **Grid_Overlay**: A configurable grid drawn over an image to assist systematic manual counting
- **Tally**: The running count total for a given Object_Type within a Session or Region
- **Annotated_Image**: The source image rendered with all Count_Markers, bounding boxes, and Region outlines drawn on top
- **CoreML_Model**: An Apple CoreML-format machine learning model that runs entirely on-device
- **Vision_Framework**: Apple's Vision framework used for image analysis and object detection
- **Undo_Stack**: A last-in-first-out stack of reversible counting operations
- **Live_Count_View**: The real-time camera viewfinder screen that performs continuous object detection on the live camera feed
- **Batch_Job**: A queued processing task that runs AI detection across multiple images sequentially
- **Export_Package**: A file or set of files produced by an export operation (CSV, JSON, PDF, or annotated image)
- **SwiftData**: Apple's Swift-native persistence framework used for local data storage
- **Sample_Object**: A user-tapped example object used to seed zero-shot AI counting

---

## Requirements

### Requirement 1: Session Management

**User Story:** As a user, I want to create, save, and manage separate counting sessions, so that I can organize counting work by project or task.

#### Acceptance Criteria

1. THE App SHALL allow the user to create a new Session with a required name and an optional description.
2. WHEN the user creates a new Session, THE App SHALL prompt the user to select at least one image source or camera mode before the Session becomes active.
3. THE App SHALL persist all Sessions locally on the device using SwiftData.
4. WHEN the user requests deletion of a Session, THE App SHALL display a confirmation dialog before permanently deleting the Session and all associated data.
5. THE App SHALL display all Sessions in a list sorted by most-recently-modified date descending.
6. WHEN the user types a search query in the Session list, THE App SHALL filter and display matching Sessions within 300 milliseconds.
7. THE App SHALL support storage of at least 1,000 Sessions on the device without degradation in list performance.
8. WHEN the user duplicates a Session, THE App SHALL create a new Session with the same Object_Types and settings but with no Count_Markers and a "(Copy)" suffix on the name.

---

### Requirement 2: Image and Video Import

**User Story:** As a user, I want to import images and videos from multiple sources, so that I can count objects in any content I have.

#### Acceptance Criteria

1. THE App SHALL allow the user to import images from the device Photos Library using the system photo picker.
2. THE App SHALL allow the user to capture a new photo directly using the device camera.
3. THE App SHALL allow the user to import video files from the device Photos Library.
4. THE App SHALL allow the user to record a new video directly using the device camera.
5. THE App SHALL allow the user to import images and videos from the Files app (iCloud Drive and local storage).
6. WHEN the user imports an image, THE App SHALL accept JPEG, PNG, HEIC, and TIFF formats.
7. WHEN the user imports a video, THE App SHALL accept MP4, MOV, and M4V formats.
8. WHEN an imported image exceeds 4096x4096 pixels, THE App SHALL generate a display thumbnail at 4096x4096 pixels while retaining the original full-resolution image for export operations.
9. IF the user denies camera or Photos Library permission, THEN THE App SHALL display an actionable alert that deep-links to the iOS Settings app for the user to grant permission.
10. THE App SHALL allow the user to add multiple images to a single Session for batch counting.

---

### Requirement 3: Manual Tap-to-Count

**User Story:** As a user, I want to mark and count objects by tapping directly on the image, so that I can precisely control which objects are counted.

#### Acceptance Criteria

1. WHEN the user taps on the image in manual counting mode, THE App SHALL place a Count_Marker at the tap location and increment the Tally of the currently selected Object_Type by 1.
2. THE App SHALL render each Count_Marker as a colored dot or icon whose color matches the Object_Type it belongs to.
3. WHEN the user long-presses an existing Count_Marker, THE App SHALL present an option to delete that Count_Marker and decrement the corresponding Tally by 1.
4. THE App SHALL support at least 10 simultaneous Object_Types per Session, each with a distinct color and icon.
5. THE App SHALL maintain an Undo_Stack of at least 50 recent counting operations.
6. WHEN the user triggers the undo action, THE App SHALL restore the previous state within 100 milliseconds.
7. THE App SHALL display the Tally for each Object_Type in real time as the user places or removes Count_Markers.
8. WHEN the user zooms or pans the image, THE App SHALL maintain the correct screen position of all Count_Markers relative to the image content.
9. THE App SHALL support pinch-to-zoom from 0.5x to 10x on the counting canvas.
10. THE App SHALL provide haptic feedback each time a Count_Marker is successfully placed.

---

### Requirement 4: Grid Overlay for Systematic Counting

**User Story:** As a user, I want to display a grid over the image, so that I can count objects systematically and avoid missing or double-counting.

#### Acceptance Criteria

1. THE App SHALL provide a toggleable Grid_Overlay in manual counting mode.
2. WHEN Grid_Overlay is enabled, THE App SHALL allow the user to configure the grid density from 2x2 to 20x20 cells.
3. THE App SHALL display a sequential cell index in each grid cell so the user can track progress.
4. WHEN the user taps a grid cell, THE App SHALL toggle that cell's "counted" state and render it with a semi-transparent highlight color.
5. THE App SHALL allow the user to customize the Grid_Overlay line color and opacity.
6. WHEN Grid_Overlay is active, THE App SHALL display the count of completed cells and total cells in the counting toolbar.

---

### Requirement 5: Zero-Shot AI Counting (On-Device)

**User Story:** As a user, I want the app to automatically detect and count objects in an image using on-device AI without requiring any template setup, so that I can count quickly without tapping every object.

#### Acceptance Criteria

1. WHEN the user activates AI counting mode, THE App SHALL run object detection using Vision_Framework and a CoreML_Model entirely on-device without requiring an internet connection.
2. THE App SHALL support zero-shot counting by allowing the user to tap a Sample_Object on the image, after which THE App SHALL detect and count all visually similar objects automatically.
3. THE App SHALL support detection of at least 80 common object categories (people, vehicles, animals, everyday objects) using a bundled YOLOv8-nano or equivalent CoreML_Model.
4. WHEN AI detection completes, THE App SHALL display a bounding box and label for each AI_Detection, annotated with its Confidence_Score.
5. THE App SHALL allow the user to adjust the Confidence_Score threshold using a slider from 0.1 to 0.9.
6. WHEN the user adjusts the Confidence_Score threshold, THE App SHALL update the displayed AI_Detections within 500 milliseconds without re-running model inference.
7. THE App SHALL allow the user to accept, edit, or delete individual AI_Detections.
8. WHEN the user accepts an AI_Detection, THE App SHALL convert the bounding box centroid into a Count_Marker for the corresponding Object_Type.
9. THE App SHALL complete AI inference on a 1920x1080 image within 3 seconds on an iPhone 12 or newer.
10. THE App SHALL display a progress indicator during AI inference.
11. IF AI inference fails due to a memory or model error, THEN THE App SHALL display a descriptive error message and offer the user the option to retry or switch to manual counting.

---

### Requirement 6: Multi-Class Counting

**User Story:** As a user, I want to count multiple different object types simultaneously in one image, so that I can analyze complex scenes in a single pass.

#### Acceptance Criteria

1. THE App SHALL allow the user to define multiple Object_Types within a single Session and count all of them simultaneously.
2. THE App SHALL display a horizontal Object_Type selector toolbar that allows the user to switch the active Object_Type with a single tap.
3. WHEN the user selects an Object_Type, THE App SHALL highlight the selected Object_Type in the toolbar and display its current Tally.
4. THE App SHALL visually distinguish Count_Markers of different Object_Types using distinct colors and optional icons.
5. THE App SHALL display a summary panel showing the Tally for every Object_Type in the current Session.
6. WHEN the user runs AI detection, THE App SHALL detect and classify objects into their respective Object_Types automatically where the model supports the category.

---

### Requirement 7: Manual and AI Hybrid Editing

**User Story:** As a user, I want to combine AI-detected results with manual corrections, so that I can achieve accurate counts even when the AI makes mistakes.

#### Acceptance Criteria

1. THE App SHALL allow the user to add Count_Markers manually on top of existing AI_Detection results.
2. THE App SHALL allow the user to delete individual AI_Detection bounding boxes that are incorrect.
3. THE App SHALL allow the user to reassign a Count_Marker or AI_Detection from one Object_Type to another by long-pressing and selecting a new type.
4. WHEN the user edits AI results, THE App SHALL update the Tally in real time to reflect the combined manual and AI count.
5. THE App SHALL visually distinguish manually placed Count_Markers from AI-converted Count_Markers (e.g., filled vs. outlined dot).
6. THE App SHALL allow the user to accept all AI_Detections above the current Confidence_Score threshold in a single "Accept All" action.
7. WHEN the user performs "Accept All", THE App SHALL convert all qualifying AI_Detections to Count_Markers and update all Tallies within 500 milliseconds.

---

### Requirement 8: Region of Interest (ROI) Counting

**User Story:** As a user, I want to draw regions on the image and count only the objects within those regions, so that I can analyze specific areas of an image independently.

#### Acceptance Criteria

1. THE App SHALL allow the user to draw a rectangular Region by dragging a finger across the image.
2. THE App SHALL allow the user to draw an elliptical Region by dragging a finger across the image.
3. THE App SHALL allow the user to draw a freehand polygon Region by tapping multiple points on the image.
4. THE App SHALL support at least 10 simultaneous Regions on a single image, each with a distinct name and color.
5. WHEN the user activates counting within a Region, THE App SHALL compute a Region-specific Tally that includes only Count_Markers and AI_Detections whose centroids fall within that Region's boundary.
6. THE App SHALL display both a per-Region Tally and a global Tally for the entire image.
7. WHEN the user resizes or repositions a Region, THE App SHALL recompute the Region Tally within 200 milliseconds.
8. THE App SHALL allow the user to assign a name to each Region for identification in reports and exports.

---

### Requirement 9: Live Camera Counting

**User Story:** As a user, I want to count objects in real time through the camera viewfinder, so that I can count objects in the physical world without taking a photo first.

#### Acceptance Criteria

1. THE App SHALL provide a Live_Count_View that activates the device camera and runs continuous AI detection on the live video feed.
2. WHEN the Live_Count_View is active, THE App SHALL display bounding boxes and Tallies overlaid on the live camera preview in real time.
3. THE App SHALL update the live detection overlay at a minimum of 15 frames per second on an iPhone 12 or newer.
4. THE App SHALL allow the user to freeze the live feed and switch to manual editing mode on the frozen frame.
5. WHEN the user freezes the live feed, THE App SHALL save the frozen frame as a new image in the current Session.
6. THE App SHALL allow the user to adjust the Confidence_Score threshold in Live_Count_View without interrupting the live feed.
7. THE App SHALL allow the user to switch between front and rear cameras in Live_Count_View.
8. IF the device does not support the required camera capabilities, THEN THE App SHALL display an informative message and disable Live_Count_View.

---

### Requirement 10: Batch Counting

**User Story:** As a user, I want to process multiple photos at once with AI counting, so that I can count objects across a large set of images efficiently.

#### Acceptance Criteria

1. THE App SHALL allow the user to select multiple images from the Photos Library or Files app and add them to a Batch_Job.
2. WHEN a Batch_Job is started, THE App SHALL run AI detection on each image sequentially and display overall progress (e.g., "3 of 10 images processed").
3. THE App SHALL allow the user to cancel a Batch_Job at any time, preserving results already processed.
4. WHEN a Batch_Job completes, THE App SHALL display a summary of total counts per Object_Type across all processed images.
5. THE App SHALL allow the user to review and edit AI results for each individual image within a Batch_Job after processing.
6. THE App SHALL allow the user to export the aggregated Batch_Job results as a single CSV or JSON file.

---

### Requirement 11: Video Frame Counting

**User Story:** As a user, I want to count objects in video by frame or time interval, so that I can analyze dynamic video content.

#### Acceptance Criteria

1. THE App SHALL allow the user to pause a video at any frame and perform manual or AI counting on that frame.
2. THE App SHALL allow the user to step through video frame by frame using swipe gestures or navigation buttons.
3. WHEN the user counts objects on a video frame, THE App SHALL store the counting result associated with the timestamp of that frame.
4. THE App SHALL allow the user to run AI detection automatically on frames sampled at a user-configurable interval (e.g., every 1 second, every 5 seconds).
5. THE App SHALL display a timeline with markers at all frames that have been counted.
6. THE App SHALL display a line chart showing the count over time for each Object_Type across all counted frames.

---

### Requirement 12: Export and Sharing

**User Story:** As a user, I want to export counting results in multiple formats, so that I can use the data in other tools or share it with others.

#### Acceptance Criteria

1. THE App SHALL allow the user to export Session results as a CSV file containing Object_Type name, Tally, Count_Marker coordinates, Region name, and timestamp.
2. THE App SHALL allow the user to export Session results as a JSON file containing the full Session metadata and all counting data.
3. THE App SHALL allow the user to export an Annotated_Image as JPEG or PNG with all Count_Markers, bounding boxes, and Region outlines rendered on the image.
4. THE App SHALL allow the user to export a PDF report containing the Annotated_Image, a per-Object_Type and per-Region Tally table, and Session metadata.
5. WHEN the user initiates an export, THE App SHALL present the iOS Share Sheet to allow sharing via AirDrop, Mail, Messages, Files, and other installed apps.
6. THE App SHALL allow the user to copy a plain-text summary of all Tallies to the clipboard with a single tap.
7. THE App SHALL complete CSV and JSON export within 2 seconds for a Session containing up to 10,000 Count_Markers.
8. WHEN a PDF export completes, THE App SHALL notify the user and offer an option to open the file immediately.

---

### Requirement 13: Counting History and Statistics

**User Story:** As a user, I want to view statistics and history for my counting sessions, so that I can understand and analyze the data I have collected.

#### Acceptance Criteria

1. THE App SHALL display the total Tally for all Object_Types in the current Session on the main counting screen.
2. THE App SHALL display a pie chart showing the proportional distribution of counts across Object_Types in a Session.
3. THE App SHALL display a bar chart comparing Tallies across Regions within a Session.
4. WHEN the user has multiple Sessions, THE App SHALL allow the user to compare the Tally of the same Object_Type across different Sessions.
5. THE App SHALL calculate and display object density (count per unit image area) for each Object_Type.
6. THE App SHALL record a timestamped history of Tally changes within a Session so the user can review the counting progression.

---

### Requirement 14: Object Type Management

**User Story:** As a user, I want to define and manage multiple object types with custom names, colors, and icons, so that I can organize counting across complex scenes.

#### Acceptance Criteria

1. THE App SHALL allow the user to add a new Object_Type with a custom name, color, and icon.
2. THE App SHALL provide an icon library containing at least 50 icons organized by theme (people, vehicles, animals, nature, objects).
3. THE App SHALL allow the user to save a set of Object_Types as a reusable template.
4. THE App SHALL provide at least 10 built-in Object_Type templates (e.g., "Inventory Check", "People Count", "Wildlife Survey").
5. WHEN the user deletes an Object_Type, THE App SHALL delete all associated Count_Markers and update all Tallies accordingly.
6. THE App SHALL allow the user to reorder Object_Types in the toolbar by drag-and-drop.

---

### Requirement 15: iCloud Backup and Sync

**User Story:** As a user, I want my counting data backed up and synced, so that I do not lose data when changing devices or reinstalling the app.

#### Acceptance Criteria

1. THE App SHALL support automatic Session backup to iCloud using CloudKit when the user is signed into iCloud.
2. WHEN the user installs the App on a new device and signs in with the same iCloud account, THE App SHALL automatically restore all backed-up Sessions.
3. THE App SHALL allow the user to enable or disable iCloud sync in the App Settings screen.
4. WHEN iCloud sync is in progress, THE App SHALL display a sync status indicator.
5. IF the iCloud connection fails, THEN THE App SHALL continue operating normally with local data and retry sync automatically when connectivity is restored.
6. THE App SHALL allow the user to export all data as a portable backup file with the `.opencount` extension for manual storage.

---

### Requirement 16: Accessibility

**User Story:** As a user with accessibility needs, I want the app to support assistive technologies, so that I can use all features regardless of visual or motor ability.

#### Acceptance Criteria

1. THE App SHALL support VoiceOver by providing meaningful accessibility labels and hints for all interactive UI elements.
2. THE App SHALL support Dynamic Type so that all text scales correctly with the user's preferred text size setting in iOS Accessibility settings.
3. THE App SHALL support both Light Mode and Dark Mode, following the system appearance setting automatically.
4. THE App SHALL support both Portrait and Landscape orientations on iPhone and iPad.
5. THE App SHALL provide haptic feedback for Count_Marker placement, undo operations, and destructive action confirmations.
6. WHEN the user performs a destructive action (delete Session, delete Object_Type, clear all markers), THE App SHALL display a confirmation dialog with a clear description of the consequence.

---

### Requirement 17: Settings and Customization

**User Story:** As a user, I want to customize the app's behavior to match my workflow, so that I can work efficiently without adjusting settings repeatedly.

#### Acceptance Criteria

1. THE App SHALL provide a Settings screen with options for: default Count_Marker size, default Count_Marker color, default AI Confidence_Score threshold, and default export format.
2. THE App SHALL allow the user to configure Count_Marker size from 16 pt to 48 pt.
3. THE App SHALL persist all user settings using UserDefaults and restore them on app launch.
4. THE App SHALL allow the user to reset all settings to factory defaults with a single action.
5. WHERE the user has enabled the "Confirm before delete marker" setting, THE App SHALL display a confirmation prompt before removing any Count_Marker.

---

### Requirement 18: Performance and Reliability

**User Story:** As a user, I want the app to be fast and stable, so that I can work efficiently without interruptions.

#### Acceptance Criteria

1. THE App SHALL launch and display the main screen within 2 seconds on an iPhone 12 or newer.
2. THE App SHALL consume no more than 200 MB of RAM during normal manual counting operations.
3. WHEN the App transitions to the background, THE App SHALL persist the current Session state within 1 second.
4. WHEN the App returns to the foreground, THE App SHALL restore the saved Session state within 500 milliseconds.
5. IF the App terminates unexpectedly, THEN THE App SHALL recover the in-progress Session including all Count_Markers on the next launch.
6. THE App SHALL support iOS 16.0 and later.
7. THE App SHALL function fully on iPhone SE (3rd generation) and all iPad models running iOS 16.0 or later.
8. THE App SHALL render the counting canvas at 60 fps during zoom, pan, and tap interactions on images up to 4096x4096 pixels.

---

### Requirement 19: AR Counting (Augmented Reality)

**User Story:** As a user, I want to count objects in the real world using augmented reality, so that I can count physical objects in 3D space without taking a photo first.

#### Acceptance Criteria

1. THE App SHALL provide an AR_Count_View that uses ARKit to overlay count markers on detected objects in the real-world camera feed.
2. WHEN the user taps an object in AR_Count_View, THE App SHALL place a persistent 3D anchor at that location and increment the Tally for the selected Object_Type.
3. THE App SHALL maintain the position of AR anchors as the user moves the device, using ARKit world tracking.
4. THE App SHALL allow the user to capture a snapshot of the AR scene with all anchors rendered as an Annotated_Image.
5. WHEN the user exits AR_Count_View, THE App SHALL save all AR-placed Count_Markers to the current Session.
6. THE App SHALL display the distance from the device to each AR anchor in meters.
7. IF the device does not support ARKit world tracking, THEN THE App SHALL display an informative message and disable AR_Count_View.
8. THE App SHALL support iOS 16.0+ ARKit on iPhone 12 or newer with LiDAR-enhanced precision on supported devices.

---

### Requirement 20: Custom CoreML Model Import

**User Story:** As a user or researcher, I want to import my own CoreML model for object detection, so that I can count domain-specific objects that the built-in model does not recognize.

#### Acceptance Criteria

1. THE App SHALL allow the user to import a `.mlpackage` or `.mlmodel` file from the Files app and use it as the active detection model.
2. WHEN a custom model is imported, THE App SHALL validate that it conforms to the Vision object detection input/output specification before activating it.
3. THE App SHALL display the model name, input size, and class labels of the active model in the Settings screen.
4. THE App SHALL allow the user to switch between the built-in YOLOv8n model and any imported custom model at any time.
5. WHEN a custom model fails validation, THE App SHALL display a descriptive error and revert to the built-in model.
6. THE App SHALL persist the selected model preference across app launches.
7. THE App SHALL support models with up to 1,000 output classes.

---

### Requirement 21: ML Training Data Export

**User Story:** As a user, I want to export my counting annotations in standard ML training formats, so that I can use my labeled data to train or fine-tune object detection models.

#### Acceptance Criteria

1. THE App SHALL allow the user to export Session annotations in COCO JSON format, including bounding boxes, class labels, and image metadata.
2. THE App SHALL allow the user to export Session annotations in YOLO TXT format (one `.txt` file per image with normalized bounding box coordinates).
3. WHEN exporting ML training data, THE App SHALL include the source images alongside the annotation files in a ZIP archive.
4. THE App SHALL allow the user to split the export into train/validation/test sets with configurable ratios (e.g., 70/20/10).
5. THE App SHALL display the total annotation count and class distribution before the user confirms the export.
6. THE App SHALL complete the ZIP export within 10 seconds for a Session containing up to 500 annotated images.

---

### Requirement 22: Apple Watch Companion

**User Story:** As a user, I want to count objects using my Apple Watch, so that I can tally counts hands-free while my iPhone is in my pocket.

#### Acceptance Criteria

1. THE App SHALL include a watchOS companion app that displays the active Session's Object_Types and current Tallies.
2. WHEN the user taps the Digital Crown or a count button on the Watch, THE App SHALL increment the Tally for the selected Object_Type and sync the result to the iPhone app via WatchConnectivity.
3. THE Watch app SHALL support haptic feedback on each count tap.
4. THE Watch app SHALL display the current Tally for each Object_Type in a scrollable list.
5. WHEN the iPhone app is not reachable, THE Watch app SHALL queue count increments locally and sync when connectivity is restored.
6. THE Watch app SHALL support complications displaying the total count for the active Session.

---

### Requirement 23: Siri Shortcuts and Widgets

**User Story:** As a user, I want to use Siri and Home Screen widgets to interact with OpenCount, so that I can start counting and check tallies without opening the app.

#### Acceptance Criteria

1. THE App SHALL donate Siri Shortcuts for: "Start counting [Object_Type] in [Session]", "Show tally for [Session]", and "Export [Session] as CSV".
2. WHEN the user invokes a Siri Shortcut, THE App SHALL perform the requested action and respond with a spoken and visual confirmation.
3. THE App SHALL provide a Home Screen widget (small, medium, large) displaying the Tally for a user-selected Session and Object_Type.
4. THE widget SHALL update its displayed Tally within 15 minutes of a change using WidgetKit's timeline provider.
5. WHEN the user taps the widget, THE App SHALL open directly to the corresponding Session in CountingView.
6. THE App SHALL support the Shortcuts app for building custom automation workflows using OpenCount actions.

---

### Requirement 24: Density Heatmap

**User Story:** As a user, I want to see a visual heatmap of where counted objects are concentrated, so that I can identify spatial patterns and hotspots.

#### Acceptance Criteria

1. THE App SHALL render a Density_Heatmap overlay on the image canvas showing the spatial distribution of Count_Markers using a color gradient (cool-to-warm).
2. THE App SHALL allow the user to toggle the Density_Heatmap on and off without losing any Count_Markers.
3. THE App SHALL allow the user to configure the heatmap radius (influence area per marker) from 10 pt to 100 pt.
4. THE App SHALL compute and render the Density_Heatmap within 1 second for sessions with up to 10,000 markers.
5. THE App SHALL allow the user to export the Density_Heatmap as a standalone PNG overlay image.
6. WHEN multiple Object_Types are present, THE App SHALL allow the user to display the heatmap for all types combined or for a single selected type.

---

### Requirement 25: Multi-Image Panorama Counting

**User Story:** As a user, I want to count objects across stitched panorama or drone mosaic images, so that I can analyze large-area surveys without splitting them into tiles manually.

#### Acceptance Criteria

1. THE App SHALL allow the user to import a high-resolution panorama or mosaic image up to 16384×16384 pixels.
2. THE App SHALL automatically tile large images into overlapping sub-regions for AI inference and deduplicate detections at tile boundaries.
3. THE App SHALL display the full panorama in a zoomable canvas with all Count_Markers correctly positioned.
4. WHEN the user exports a panorama Session, THE App SHALL produce a full-resolution Annotated_Image with all markers rendered at their correct positions.
5. THE App SHALL complete AI inference on a 16384×16384 image within 30 seconds on an iPhone 14 Pro or newer.

---

### Requirement 26: Counting Templates Marketplace (iCloud Sharing)

**User Story:** As a user, I want to share and discover Object_Type templates created by other users, so that I can quickly set up counting for common use cases.

#### Acceptance Criteria

1. THE App SHALL allow the user to publish a set of Object_Types as a shareable Template via a CloudKit public database.
2. THE App SHALL provide a Template_Gallery screen where users can browse, search, and preview community-shared templates.
3. WHEN the user installs a template from the gallery, THE App SHALL add the template's Object_Types to the current Session.
4. THE App SHALL allow the user to rate templates (1–5 stars) and display average ratings in the gallery.
5. THE App SHALL allow the user to report inappropriate templates, which flags them for review.
6. THE App SHALL display the download count and author name for each published template.

---

### Requirement 27: Shortcuts App Deep Integration

**User Story:** As a power user, I want to build automated counting workflows using the iOS Shortcuts app, so that I can chain OpenCount actions with other apps and automations.

#### Acceptance Criteria

1. THE App SHALL expose the following actions to the Shortcuts app via App Intents: Create Session, Add Image to Session, Run AI Counting, Get Tally, Export Session, and Delete Session.
2. WHEN a Shortcut action runs, THE App SHALL execute the action in the background without requiring the app to be in the foreground.
3. THE App SHALL return structured output (session ID, tally dictionary, file URL) from each Shortcut action for use in subsequent Shortcut steps.
4. THE App SHALL provide at least 3 pre-built Shortcut templates in the Shortcuts gallery (e.g., "Count and Email Report", "Daily Inventory Check", "Wildlife Survey Workflow").

---

### Requirement 28: Collaborative Session Sharing

**User Story:** As a team member, I want to share a counting session with colleagues so that multiple people can contribute counts to the same session.

#### Acceptance Criteria

1. THE App SHALL allow the user to share a Session via a CloudKit share link that recipients can open to join the Session.
2. WHEN multiple users are active in a shared Session, THE App SHALL merge Count_Markers from all participants using CloudKit's conflict resolution.
3. THE App SHALL display the name or initials of the participant who placed each Count_Marker.
4. THE App SHALL show a live participant list with online/offline status in the shared Session.
5. WHEN a participant adds or removes a marker, THE App SHALL propagate the change to all other participants within 5 seconds under normal network conditions.
6. THE App SHALL allow the Session owner to revoke access for any participant.
7. THE App SHALL support up to 10 simultaneous participants per shared Session.

---

### Requirement 29: Onboarding and First-Run Experience

**User Story:** As a new user, I want a guided introduction to the app's key features, so that I can start counting effectively without reading documentation.

#### Acceptance Criteria

1. THE App SHALL display an onboarding flow of at most 5 screens on the very first launch, covering: creating a session, placing a manual marker, running AI counting, drawing a region, and exporting results.
2. WHEN the user completes or skips onboarding, THE App SHALL persist the completion state using `AppStorage` and never show the full onboarding flow again.
3. THE App SHALL provide a "Replay Tutorial" option in the Settings screen that re-launches the onboarding flow on demand.
4. WHEN the user opens a feature for the first time (AI counting, Live Camera, AR, Batch), THE App SHALL display a contextual tooltip or coach mark explaining that feature's primary action.
5. Each coach mark SHALL be dismissible with a single tap and SHALL NOT block the user from interacting with the underlying UI.
6. THE App SHALL provide an interactive sample session pre-loaded with example images and markers so the user can explore the interface without importing their own content.
7. WHEN the user deletes the sample session, THE App SHALL offer to restore it from the Settings screen.

---

### Requirement 30: Localization and Internationalization

**User Story:** As a non-English-speaking user, I want the app to be available in my language, so that I can use all features comfortably.

#### Acceptance Criteria

1. THE App SHALL support at least the following locales at launch: English (en), Vietnamese (vi), Japanese (ja), Simplified Chinese (zh-Hans), French (fr), German (de), Spanish (es), Portuguese (pt-BR), Korean (ko), and Arabic (ar).
2. ALL user-visible strings SHALL be externalized into `.xcstrings` (String Catalog) files and SHALL NOT be hardcoded in source code.
3. THE App SHALL support right-to-left (RTL) layout for Arabic and other RTL locales, with all UI elements mirrored correctly.
4. WHEN the device locale changes, THE App SHALL apply the new locale on the next app launch without requiring reinstallation.
5. ALL date, time, number, and unit values displayed in the UI SHALL be formatted using the device's current locale via `Foundation` formatters.
6. THE App SHALL localize all export file content (CSV headers, PDF labels, JSON field descriptions) to match the active locale.
7. THE App SHALL support locale-aware search so that session name filtering works correctly for Unicode characters (e.g., Vietnamese diacritics, CJK characters).

---

### Requirement 31: iPad-Optimized and Apple Pencil Support

**User Story:** As an iPad user, I want the app to take full advantage of the larger screen and Apple Pencil, so that I can count and annotate with precision.

#### Acceptance Criteria

1. THE App SHALL support iPad Split View and Slide Over multitasking, adapting its layout to any column width from 320 pt to full screen.
2. THE App SHALL support Stage Manager on iPadOS 16+, allowing the app window to be freely resized.
3. WHEN running on iPad, THE App SHALL display a two-column layout in `SessionListView`: the session list on the left and the active `CountingView` on the right using `NavigationSplitView`.
4. THE App SHALL support Apple Pencil (1st and 2nd generation) for placing Count_Markers with sub-pixel precision.
5. WHEN the user draws a region with Apple Pencil, THE App SHALL use `PencilKit` to capture the stroke and convert it to a freehand polygon `CountRegion`.
6. THE App SHALL support Apple Pencil double-tap (2nd generation) to toggle between the active Object_Type and the region-drawing tool.
7. THE App SHALL support Apple Pencil hover (iPadOS 16.1+ with compatible hardware) to preview marker placement before the tip touches the screen.
8. THE App SHALL support the iPad keyboard shortcut overlay: `⌘N` for new session, `⌘Z` / `⌘⇧Z` for undo/redo, `⌘E` for export, `Space` to toggle AI counting.

---

### Requirement 32: In-App Feedback and Crash Reporting

**User Story:** As a user, I want to report bugs and suggest features directly from the app, so that I can help improve OpenCount without leaving the app.

#### Acceptance Criteria

1. THE App SHALL provide a "Send Feedback" option in the Settings screen that opens a feedback composer with fields for: feedback type (Bug / Feature Request / Other), description, and an optional screenshot attachment.
2. WHEN the user submits feedback, THE App SHALL send it to the project's GitHub Issues API (or a configured webhook endpoint) using a background `URLSession` task.
3. THE App SHALL automatically attach non-personally-identifiable diagnostic information to each feedback submission: iOS version, device model, app version, and build number.
4. THE App SHALL integrate a lightweight crash reporting mechanism (using `MetricKit` and `MXCrashDiagnostic`) that collects crash logs on-device and presents them to the user on the next launch with an option to submit.
5. WHEN a crash report is available, THE App SHALL ask the user for consent before transmitting any data.
6. THE App SHALL allow the user to opt out of all diagnostic data collection in the Settings screen; this preference SHALL be persisted and respected on every launch.
7. THE App SHALL display the current app version, build number, and a link to the GitHub repository in the Settings screen's "About" section.

---

### Requirement 33: Offline-First UX and Network Status

**User Story:** As a user in a low-connectivity environment, I want the app to clearly communicate its offline/online state and continue working fully offline, so that I am never blocked by network issues.

#### Acceptance Criteria

1. THE App SHALL function with 100% of its core features (manual counting, AI counting, export, session management) without any network connection.
2. WHEN the device has no network connectivity, THE App SHALL display a non-intrusive status banner indicating offline mode; this banner SHALL disappear automatically when connectivity is restored.
3. THE App SHALL queue all iCloud sync operations locally when offline and flush the queue automatically when connectivity is restored, without user intervention.
4. WHEN a network-dependent feature (Template Marketplace, Collaborative Session, Feedback submission) is accessed while offline, THE App SHALL display a clear message explaining that the feature requires connectivity and offer to retry when online.
5. THE App SHALL never display a loading spinner indefinitely; all network operations SHALL have a timeout of at most 30 seconds, after which THE App SHALL display an actionable error with a retry option.
6. THE App SHALL cache the last-fetched Template Marketplace results locally so that previously viewed templates are browsable while offline.

---

### Requirement 34: Advanced Image Annotation Tools

**User Story:** As a power user, I want additional annotation tools beyond basic markers, so that I can add context and notes directly on the image.

#### Acceptance Criteria

1. THE App SHALL allow the user to add a text annotation label at any point on the image canvas, with configurable font size and color.
2. THE App SHALL allow the user to draw straight measurement lines on the image canvas and display the line length in normalized image units.
3. THE App SHALL allow the user to add arrow annotations pointing to specific objects on the image.
4. ALL annotation types (text labels, lines, arrows, Count_Markers, regions) SHALL be included in the Annotated_Image and PDF exports.
5. THE App SHALL allow the user to show or hide each annotation layer independently using a layer panel.
6. WHEN the user exports an Annotated_Image, THE App SHALL allow them to choose which annotation layers to include in the export.

---

### Requirement 35: Smart Count Suggestions and Duplicate Detection

**User Story:** As a user doing manual counting, I want the app to warn me about potential duplicates and suggest objects I may have missed, so that I can achieve more accurate counts.

#### Acceptance Criteria

1. WHEN the user places a Count_Marker within 20 normalized pixels of an existing marker of the same Object_Type, THE App SHALL display a non-blocking warning: "Possible duplicate — are you sure?"
2. THE App SHALL provide a "Find Missed Objects" action that runs a secondary AI pass at a lower confidence threshold (0.2) and highlights detections not yet covered by any existing marker.
3. WHEN "Find Missed Objects" completes, THE App SHALL display the candidate detections in a distinct color and allow the user to accept or dismiss each one individually.
4. THE App SHALL track counting velocity (markers placed per minute) and display a fatigue warning if the user places more than 60 markers per minute for more than 2 consecutive minutes.
5. THE App SHALL provide a "Review Mode" that steps through all Count_Markers one by one, centering each on screen, so the user can verify each counted object.


---

### Requirement 36: Count History Timeline and Audit Log

**User Story:** As a user, I want a complete, timestamped history of every counting operation in a session, so that I can audit my work, undo to any point in time, and understand how counts evolved.

#### Acceptance Criteria

1. THE App SHALL record every tally-changing operation (marker add, marker remove, AI accept, marker reassign) as a `CountHistoryEntry` with a timestamp and source (manual, AI, Watch, Shortcut).
2. THE App SHALL provide a `CountHistoryView` displaying all history entries for a session in chronological order, grouped by date.
3. WHEN the user selects a history entry, THE App SHALL offer to restore the session state to that point in time (undo-to-point).
4. THE App SHALL allow the user to export the audit log as a CSV file with columns: timestamp, operation, object_type, marker_id, source.
5. THE App SHALL display a sparkline chart in the session list row showing counting activity over the last 7 days.

---

### Requirement 37: On-Device AI Fine-Tuning

**User Story:** As a researcher or domain expert, I want to fine-tune the AI model using my own annotated data, so that I can improve detection accuracy for my specific objects without leaving the app.

#### Acceptance Criteria

1. THE App SHALL allow the user to select any session with AI-derived markers as training data for fine-tuning the bundled CoreML model using the `CreateML` framework.
2. THE App SHALL display a live training loss chart during fine-tuning using Swift Charts.
3. THE App SHALL allow the user to configure the number of training epochs (5–50) and learning rate before starting fine-tuning.
4. WHEN fine-tuning completes, THE App SHALL save the resulting model as a `.mlpackage` file and register it via `CustomModelService`.
5. THE App SHALL run fine-tuning entirely on-device with no data leaving the device.
6. THE App SHALL display estimated training time before the user starts fine-tuning.

---

### Requirement 38: Multi-Device Handoff

**User Story:** As a user who works across multiple Apple devices, I want to seamlessly hand off a counting session from one device to another, so that I can continue my work without interruption.

#### Acceptance Criteria

1. THE App SHALL implement `NSUserActivity` with `activityType = "com.opencount.counting"` so that an active counting session can be handed off to another nearby Apple device via Handoff.
2. WHEN the user accepts a Handoff on another device, THE App SHALL open directly to the same session and image that was active on the source device.
3. THE App SHALL support Universal Clipboard so that a tally summary copied on one device is available on nearby devices.
4. WHEN the user taps "Continue on Mac" in the Export Sheet, THE App SHALL hand off the export operation to the macOS Catalyst version of the app if available.

---

### Requirement 39: WCAG 2.1 AA Accessibility Compliance

**User Story:** As a user with visual or motor impairments, I want the app to fully comply with WCAG 2.1 AA accessibility standards, so that I can use every feature with assistive technologies.

#### Acceptance Criteria

1. ALL interactive elements SHALL have `accessibilityLabel`, `accessibilityValue`, and `accessibilityHint` set correctly for VoiceOver.
2. THE confidence threshold slider SHALL support `accessibilityAdjustableAction` for VoiceOver swipe-up/down adjustment.
3. ALL Swift Charts charts SHALL provide `accessibilityChartDescriptor` for VoiceOver audio graph support (iOS 16+).
4. THE App SHALL support Switch Control with a logical scanning order for all major screens.
5. WHEN `UIAccessibility.isReduceMotionEnabled` is `true`, THE App SHALL replace all spring animations with opacity transitions.
6. THE App SHALL pass `XCUIElement.performAccessibilityAudit()` (Xcode 15+) with zero critical violations on all major screens.

---

### Requirement 40: Performance Dashboard

**User Story:** As a developer or power user, I want to see real-time performance metrics for the app, so that I can diagnose slowdowns and verify the app meets its performance targets.

#### Acceptance Criteria

1. THE App SHALL provide a hidden `PerformanceDashboardView` accessible via a tap sequence in Settings (developer/beta mode only).
2. THE dashboard SHALL display: live FPS for `ImageCanvas`, current RAM usage, AI inference latency histogram (last 20 runs), and active network tasks.
3. THE App SHALL allow the user to export a JSON diagnostics report from the dashboard via the iOS Share Sheet.

---

### Requirement 41: Count Verification QR Code

**User Story:** As a user who needs to share or verify counting results, I want to generate a tamper-evident QR code summarizing a session's tally, so that recipients can verify the count without accessing the full session.

#### Acceptance Criteria

1. THE App SHALL generate a QR code encoding a compact JSON payload containing: session name, date, per-Object_Type counts, and a SHA-256 hash of the payload for tamper detection.
2. THE App SHALL display the QR code in a `QRCodeView` with the session name and date below it.
3. THE App SHALL allow the user to share the QR code as a PNG via the iOS Share Sheet.
4. THE App SHALL provide a QR scanner in `SessionListView` that reads an OpenCount QR code and displays the tally summary or navigates to the matching local session.
5. THE App SHALL offer to embed the QR code in the PDF report footer when exporting.

---

### Requirement 42: Count Targets and Progress Tracking

**User Story:** As a user with a specific counting goal, I want to set a target count for each object type and see my progress toward that target, so that I know when I have reached my goal.

#### Acceptance Criteria

1. THE App SHALL allow the user to set an optional target count for each `ObjectType` in `ObjectTypeEditorView`.
2. WHEN a target is set, THE App SHALL display a progress ring around the tally badge in the Object_Type toolbar, filling as the count approaches the target.
3. WHEN the count first reaches the target, THE App SHALL trigger a success haptic and a brief confetti animation.
4. WHEN the count exceeds the target, THE App SHALL display the ring in red to indicate overage.
5. THE App SHALL display target progress as a horizontal progress bar per Object_Type in `StatisticsView`.
6. THE App SHALL include target and progress data in CSV and JSON exports.

---

### Requirement 43: Full Session Templates

**User Story:** As a user who repeats similar counting tasks, I want to save and reuse complete session configurations including object types, regions, and targets, so that I can start new sessions instantly without reconfiguring.

#### Acceptance Criteria

1. THE App SHALL allow the user to save any session as a private template stored locally in SwiftData.
2. THE App SHALL list private templates in `NewSessionSheet` for one-tap session creation.
3. THE App SHALL support full session templates (Object_Types + default regions + target counts) in the Template Marketplace, in addition to Object_Type-only templates.
4. WHEN a newer version of an installed template is published, THE App SHALL display an "Update available" badge on the template in `TemplateGalleryView`.
5. THE App SHALL allow the user to import a template from a direct CloudKit share URL.

---

### Requirement 44: Local REST API and Extended URL Scheme

**User Story:** As a power user or developer, I want to control OpenCount programmatically from other apps or scripts, so that I can integrate counting into automated workflows.

#### Acceptance Criteria

1. THE App SHALL provide an opt-in local HTTP server on `localhost:47200` exposing: `GET /sessions`, `GET /sessions/{id}/tally`, `POST /sessions/{id}/markers`, `GET /sessions/{id}/export?format=csv|json`.
2. THE local server SHALL be disabled by default and toggled in Settings under "Developer Tools".
3. THE App SHALL extend the `opencount://` URL scheme with: `opencount://session/<id>`, `opencount://new-session?name=<n>`, `opencount://tally/<sessionID>/<objectType>`.
4. WHEN the local server is first enabled, THE App SHALL write a `README-API.md` to the app's Documents directory documenting all endpoints and URL scheme actions.

---

### Requirement 45: App Clip for Quick Count

**User Story:** As a user who needs to count quickly without installing the full app, I want an App Clip that opens directly to live AI counting, so that I can get a count in seconds.

#### Acceptance Criteria

1. THE App SHALL provide an App Clip (`OpenCountClip`) invokable via NFC tag or QR code encoding `https://opencount.app/clip?session=<id>`.
2. THE App Clip SHALL open directly to a live camera counting view with AI detection overlay and tally display.
3. THE App Clip SHALL use a quantized INT8 CoreML model to stay under the 15 MB App Clip size limit.
4. WHEN the App Clip is closed, THE App SHALL prompt the user to install the full OpenCount app via `SKOverlay`.

---

### Requirement 46: macOS Catalyst Support

**User Story:** As a Mac user, I want to use OpenCount natively on macOS, so that I can count objects in images on my desktop with the same features as the iOS app.

#### Acceptance Criteria

1. THE App SHALL support macOS Catalyst (Mac Idiom: Scaled) targeting macOS 13.0+.
2. WHEN running on macOS, THE App SHALL support mouse click to place markers, right-click for context menu, and scroll wheel for zoom.
3. WHEN running on macOS, THE App SHALL use `NSSharingServicePicker` instead of `UIActivityViewController` for sharing.
4. WHEN running on macOS, THE App SHALL support drag-and-drop image import from Finder.
5. THE App SHALL provide a macOS menu bar with items: File > New Session, Edit > Undo/Redo, Session > Run AI Counting, Session > Export.

---

### Requirement 47: Counting Velocity and Fatigue Management

**User Story:** As a user doing extended manual counting sessions, I want the app to monitor my counting pace and warn me when I may be fatiguing, so that I can maintain accuracy over long sessions.

#### Acceptance Criteria

1. THE App SHALL track counting velocity as markers placed per minute using a sliding 60-second window.
2. WHEN counting velocity exceeds 60 markers per minute for more than 2 consecutive minutes, THE App SHALL display a dismissible fatigue warning banner.
3. THE App SHALL display the current counting velocity in the counting toolbar as an optional overlay (toggleable in Settings).
4. THE App SHALL record velocity data in the `CountHistoryEntry` audit log for post-session analysis.
