## TTLinfo columns
### Column 1: Master NIDAQ Hardware Clock
  - Signal Type: Continuous Monotonic Timestamp (seconds).
  - Role: The master timebase recorded directly by the NIDAQ board hardware clock (typically sampled at 5 kHz). Every hardware pulse detected on channels 2 through 12 reads its exact time directly from this column.

### Column 3: fUSI Acquisition Frames
  - Signal Type: Frame Acquisition Sync Trigger.
  - Role: A pulse emitted by the ultrasound scanner every time a 2D Power Doppler Imaging (PDI) frame finishes processing. 
  - Detection Logic: A falling edge (diff < 0) indicates the exact millisecond a single 3D image volume (x, z) was completed, locking that specific image frame to the master clock.

### Column 6 (Fallback: Column 5): Experiment Start (initTTL)
  - Signal Type: Master Synchronization Trigger.
  - Role: The "GO" pulse sent by the task-control system when the experimental protocol launches.
  - Why it matters: This rising edge (diff > 0) defines t = 0.00 s for the entire session. All preceding pre-trial baseline data and initialization noise (like the 6.77 s offset) are discarded relative to this pulse.

### Column 10: Visual Stimulation
  - Signal Type: Visual Task Gate.
  - Role: High voltage during active visual stimulation (e.g., screen checkerboard/flashes); low voltage during inter-trial rest.
  - Detection Logic: 
    * Rising Edge (diff > 0): Stimulus ON (startTime).
    * Falling Edge (diff < 0): Stimulus OFF (endTime).

### Column 11: Auditory Stimulation
  - Signal Type: Audio Task Gate.
  - Role: High voltage duration corresponds directly to sound presentation (e.g., pure tone or conditioned stimulus CS).
  - Detection Logic: Rising and falling edges set auditory startTime and endTime.

### Columns 4, 5, and 12: Somatosensory / Focused Ultrasound / Secondary Stimuli
  - Signal Type: High-voltage trigger lines for somatosensory, electrical, or ultrasonic neuromodulation.
  - Role & Logic:
    * Column 4: Dedicated trigger line for Focused Ultrasound Stimulation (FUS) onset.
    * Column 5: Multi-use line acting as a tail-shock trigger or secondary fallback initialization pulse.
    * Column 12: Auxiliary channel used for secondary electrical shock lines (shockOBS vs shockCTL).
    * Note: Because older setups routed these modalities across varying pins, the script checks across all three (Column 4 | Column 5 | Column 12) to catch whichever physical BNC cable was plugged in.
