# Privacy

Models and notes stay in this app's private Application Support directory. Import uses access granted by the system file picker and copies the selected model; the source file is unchanged. Archive is reversible and does not delete model bytes.

The app has no analytics, accounts, external model provider, or upload service. The network client entitlement supports Apple's Spatial Preview connection. Selecting **Present on Vision Pro** sends the selected model to the device chosen in the system picker. System presentation and collaboration behavior is governed by Apple's controls. Notes are not sent with the model.

JSON export contains the product title, timestamps, identifiers, notes, resolution state, and archive state. It excludes the model and original source path. Review exported notes before sharing them.

The source contains no credentials or signing identity. Debug UI tests use an isolated library identifier; that override is absent in Release.
