# group-project-metrojuicepaak
group-project-metrojuicepaak created by GitHub Classroom


1. App Launch - Request Permissions

App starts
   ↓
Request microphone permission (AVAudioApplication)
   ↓
Configure audio session for recording
   ↓
App is ready to record when user presses a pad



2. User Presses Pad (Start Recording)

User touches SamplerPadButton
   ↓
handlePadPressed(id) called
   ↓
AudioService.startRecording(for: id) [async]
   ↓
AVAudioRecorder/AudioKit starts capturing mic input
   ↓
Audio data streams to temporary file


3. User Releases Pad (Stop & Save)

User releases SamplerPadButton
   ↓
handlePadReleased(id) called
   ↓
AudioService.stopRecording(for: id) [async]
   ↓
Finalize recording file
   ↓
Calculate duration
   ↓
Create AudioSample(url: tempFileURL, duration: calculatedDuration)
   ↓
ViewModel loads AudioSample into SamplerPad
   ↓
UI updates (pad changes color/state)


File Storage Strategy

Temporary Recording Flow:
1. Create unique filename: "recording_\(pad​Id​.uuid​String).m4a"
2. Store in File​Manager​.default​.temporary​Directory
3. When recording stops, either:
   • Keep in temp (cleared when app closes)
   • Move to Documents (persist between sessions)
   
Example path:   
/tmp/recording_550e8400-e29b-41d4-a716-446655440000.m4a
