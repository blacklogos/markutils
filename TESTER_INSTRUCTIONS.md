# How to Open Clip (Testing Version)

Since this is a test version of the app and not downloaded from the App Store, macOS may show an error saying:
> **"Clip" is damaged and can't be opened. You should move it to the Trash.**

This is a standard security message for unsigned apps.

## Solution

To open the app, you need to remove the "Quarantine" attribute that macOS adds to downloaded files.

1.  **Install the App**: Drag `Clip.app` from the DMG to your **Applications** folder (or anywhere else).
2.  **Run the Command**: Open the **Terminal** app and paste the following command:

    ```bash
    xattr -cr /Applications/Clip.app
    ```

    *(Note: If you put the app somewhere else, change the path accordingly. You can also type `xattr -cr ` (with a space at the end) and then drag the Clip app onto the terminal window).*

3.  **Open the App**: You can now double-click `Clip` to open it normally.
