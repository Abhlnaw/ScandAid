# Privacy and storage

Native apps store versioned JSON in the application-support directory: prepared JPEGs, optional masks, outlines, references, notes, provenance and settings. Writes use pending-file/rename replacement with recovery after an interrupted rename. Successful writes remove the old backup, so deleted photos do not remain in that backup. Filesystem deletion is not secure erasure; copies in user/device backups can remain.

Web journals use browser storage. Its quota may be reached before the app's 100-scan limit; export and remove older entries as needed. Private browsing, site-data deletion or changing origin can lose or isolate records. JSON exports are the portable backup; restore validates and merges new IDs without overwriting existing entries.

Prepared photos have orientation applied, their long edge capped at 1600 pixels, and EXIF/ICC metadata explicitly cleared before re-encoding. The test suite checks orientation and identifier removal. Original source files are unchanged.

There are no analytics or automatic photo uploads. Enabling a server authorizes each later Analyze action to send the prepared photo and region to that selected address. Test connection sends only a health request. Inference uses local weights; it does not send photos to model download providers. Accepted uploads remain in RAM; request-size limits run before parsing to prevent disk spooling. The backend keeps no photo database, and the launcher disables default access logs.

App snapshots and exports are **not encrypted by ScandAid**. Use device encryption and access controls. OS camera/photo prompts apply. Android automatic app-data backup is disabled. Export deliberately saves photos and notes to the destination the user chooses, which may have its own sync/sharing behavior.

The API has no authentication and the launcher binds to `127.0.0.1`. CORS is restricted, but CORS is not authentication. Remote use needs a separately configured authenticated HTTPS gateway; changing the bind address alone is insufficient.
