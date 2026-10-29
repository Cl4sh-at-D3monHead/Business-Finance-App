🚀 How to Install and Run Ledger on macOS

Because this application is automatically compiled via GitHub Actions without an expensive Apple Developer signature, macOS will initially restrict it from opening using a standard double-click.
Follow these simple terminal commands to authorize the app package and run it natively on your Mac.

Step 1: Download the App

1. Go to the Actions tab at the top of this GitHub repository page.
2. Click on the latest workflow run that has a green checkmark next to it.
3. Scroll all the way down to the Artifacts section at the very bottom of the page.
4. Click on Ledger-Mac-Desktop-App to download the project folder.
5. Move the extracted Ledger.app bundle into your Mac's Downloads folder.

Step 2: Configure Executable Permissions

1. Open your Mac's Terminal app (Press Cmd + Space, type Terminal, and hit Enter).
2. Copy and paste this exact command into the Terminal window to make the app executable, then press Enter:bash
chmod +x /Users/jojo/Downloads/Ledger.app/Contents/MacOS/Ledger
Use code with caution.

Step 3: Clear the Gatekeeper Internet Quarantine Flag

1. Copy and paste this administrative clearance command into your Terminal window and press Enter:bash
sudo xattr -cr /Users/jojo/Downloads/Ledger.app
Use code with caution.
2. Terminal will ask for your Mac system Password. Type your normal laptop login password and press Enter.
(Note: The terminal screen will remain completely blank as you type your password for security. Type it carefully and hit Enter).

Step 4: Clear the App Damage Warning Flag (If Needed)

If your Mac throws a secondary alert stating that the app "is damaged and cannot be opened," copy, paste, and run this final line to clear the internet archive block:
bash
sudo xattr -rd com.apple.quarantine /Users/jojo/Downloads/Ledger.app

Step 5: Launch the App!

Go back to your Downloads folder and double-click the orange Ledger icon. The application will now open completely unhindered with zero security dialog blocks.
