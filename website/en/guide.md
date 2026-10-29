---
title: FileMint User Guide
description: Learn to create files in Finder, reuse templates, batch rename, calculate checksums, compress images and run OCR. Includes menu and folder access troubleshooting.
pageClass: guide-page
---

# FileMint User Guide

Start by creating one file in Finder, then turn on the other features as you need them. If FileMint is not installed yet, follow the [installation guide](./install). Screenshots show example files, apps and settings; your initial setup may differ and the interface may change between releases.

## Complete the first-time setup

1. Open FileMint from Applications. If the **General** page says the Finder extension is off, click **Open Extension Settings**, enable FileMint in macOS, then return to the app to check its status.
2. Open **Finder & Folders**. Check that your working folder is in the menu scope. If its row says **Choose this folder once**, click **Authorize…** and select that folder in the system picker.
3. Return to Finder. Right-click the **desktop or the background of a configured folder** and look for **New File**.

On macOS 15 and later, the extension switch is usually under **System Settings → General → Login Items & Extensions → Finder**. On older systems, look under **Privacy & Security → Extensions**. Finder enablement and folder access are separate. Even with Full Disk Access enabled, select your working folder when FileMint asks so it can remember sandbox access.

Prefer to work without Finder menus? **New File…** in the app sidebar and **Resource Tools → Use Tools** work directly in the main app.

## Create a file where you are

### Make a common file in one step

Right-click the desktop or a folder background in Finder, open **New File**, then choose an enabled format such as **Text (.txt)** or **Markdown (.md)**. FileMint creates the file immediately in the location you clicked. If that name already exists, the default behavior is to add a number.

### Choose the name and starter content

For a specific filename, destination or first paragraph, choose **New File → New File…**. Enter a full filename such as `project-kickoff.md`, check the format and destination, optionally type starter content, then click **Create**. **Cancel** writes nothing.

![New File panel showing the filename, format, destination, starter content, Cancel and Create controls](/images/create-panel-en.jpg)

<p class="guide-caption">Check the name, format, location and content before creating the file.</p>

A complete filename determines the suffix; choosing a different format updates the name. Starter content is saved exactly as entered. A custom suffix creates a text file; it does not convert text into a Word, Excel or image file.

App, menu-bar and Quick Search creation entries also open this panel directly, without a preliminary folder picker. Change the destination using Save Location. macOS may still request folder authorization when write access is missing.

**Keyboard:** Use Tab / Shift-Tab to move between controls, ⌘↩ to create, and Esc to cancel. Return inserts a newline in the content editor. The Paste button reads clipboard text only when you click it.

### Create a text file from the clipboard

Copy one plain-text item, then choose **New File from Clipboard…** in Finder's **New File** menu, the app or the menu bar. FileMint reads the text once and prefills the creation panel. You can change the name, format, destination and text. Only **Create** writes a file; cancelling saves nothing. File references, multiple clipboard items and empty content are not created as text files.

## Find actions, templates and settings with Quick Search

Choose **File → Quick Search…** or press Command-Shift-K in FileMint. Type a query and narrow it with Actions, Templates, Favorites or Settings. Use arrow keys to select, Return to execute and Esc to close. Command-1 through Command-5 select All and the four categories. Dismissal retains the session's query and selection; successful execution resets them.

To open search from another app, enable **Enable Global Shortcut** under **General → Quick Search**. First enable suggests Control-Option-K; you can record another combination. The switch starts off, and quitting FileMint releases the shortcut. Choose another combination if the app reports a conflict.

## Save reusable templates

Open **Templates & Types**, enable and reorder the formats you use. Click **New Text Template…** to add a template name, default filename and starter content. You can keep several templates for one suffix and choose a default. Select the template later from Finder or the creation panel.

![Templates and Types settings with New Text Template, Import Document Template and the format list](/images/file-types-en.jpg)

<p class="guide-caption">Enabled formats appear in Finder's quick creation menu.</p>

New installations enable **Word Document** and **Excel Workbook** by default. Select either to create a blank `.docx` or an `.xlsx` with one empty worksheet. Upgrades append these templates disabled; enable them in Templates & Types when needed. Creation requires neither an import nor an Office installation.

To reuse an existing Word or Excel document, click **Import Document Template…** and select a `.docx` or `.xlsx`. FileMint keeps an independent local copy. Choosing that template creates a new document with the original formatting and content; it does not change the source. An existing output name is numbered automatically.

## Save a clipboard image as PNG

1. Copy a screenshot or bitmap image.
2. Choose **Paste Image as File…** from the FileMint sidebar or Finder's **New File** menu.
3. Check the preview, filename and destination, then click **Create**.

FileMint reads the image only when you choose this action. Cancelling creates nothing. This action saves PNG and numbers an existing filename automatically.

## Open selected items or the current folder with your apps

Open **Extensions → Open with App**, click **Add App**, choose a local application, and place it in Finder's main menu or the **Open with App** submenu. Then select an item or right-click a folder background in a configured Finder location and choose the app. One ordinary selected folder is also passed as a directory.

![Open with App settings showing configured applications and individual menu positions](/images/open-with-en.jpg)

<p class="guide-caption">These applications are an example. A new installation starts with an empty list.</p>

Supported terminals offer **Follow App**, **New Tab** and **New Window** in the same settings row. File selections retain their existing opening behavior. Actual window behavior depends on the installed terminal and its macOS service. This does not change macOS default file associations. If an app is missing from the menu, check that it is still installed at its configured location and that the target folder is within the menu scope.

## Enable File & Folder Tools when needed

Open **Extensions → File & Folder Tools**, enable the master switch, then enable the actions you want. Each action can appear in Finder's main menu or the **File & Folder Tools** submenu. The master switch starts off.

![File and Folder Tools settings showing action switches and menu placement controls](/images/file-tools-en.jpg)

<p class="guide-caption">This is an example with tools enabled. Check the Permanent Delete setting before using it.</p>

- **Copy Names / Paths:** Select one or more items, then use the context menu. Multiple items are copied one per line. With Copy Paths enabled, you can also right-click an in-scope folder background to copy that folder's full path.
- **Move File / Folder:** Select the source items and choose this action. Then right-click the **background of the destination folder** and choose **Move Selected Items Here**. The first step only remembers the sources; existing names are never overwritten or merged.
- **Delete Permanently:** Bypasses Trash and asks for confirmation by default. It cannot be undone. Enable it only when you need it.
- **AirDrop / Send Alias to Desktop:** AirDrop opens the native macOS chooser so you select a recipient. An alias points to the original item without moving it.

### Copy File Contents

Enable the module and Copy File Contents in File & Folder Tools, then right-click one supported ordinary local text file in Finder. Clipboard publication follows a complete read; if you copy something else while it runs, the older request does not overwrite your newer clipboard.

Enable this child tool, then right-click one supported ordinary local text file to copy its complete contents. Accept UTF-8, BOM-declared UTF-16 and a limited validated RTF subset, with source and decoded text each limited to 8 MiB. Preserve whitespace and line endings without truncation; failure or cancellation leaves the clipboard untouched. Images, PDF, Office documents, RTF attachments and tables are unsupported.

### Batch Rename

Number a photo collection, organize project files, or apply a list of names you already have. Preview the changes first. This tool starts off.

1. In **Extensions → File & Folder Tools**, enable the master switch and **Batch Rename**.
2. Select 2–1,000 ordinary files or folders **in one Finder directory**, then choose **Batch Rename…**. Current support is local, writable APFS, subject to system permissions and the actual state of the files.
3. In **Rules**, combine replacement, deletion, prepended/appended text, numbering or case rules in order. Or choose **Name List** and paste one name **without its protected extension** per item, following the preview order.
4. Compare original and new names, check the status, then click **Rename N Items**. Conflicts and invalid names block execution without overwriting existing items.

![Batch Rename window with a unified name and numbering rule, original and new names, and per-item status](/images/batch-rename-en.jpg)

<p class="guide-caption">Example numbering rule. Extensions and hidden status stay unchanged; the preview itself does not rename files.</p>

Each name-list line contains only the name body; do not repeat the extension. Files without an extension cannot gain one through the new name. Return edits the focused field without renaming the batch. After reviewing the preview, use the button or ⌘↩ to execute.

**To undo:** Choose **Undo Last Batch Rename…** in the result panel or the app's **File** menu, then review and confirm the reverse preview for the most recent successful operation. Interrupted operations offer restoration of their pre-operation names. If manual handling is needed, export recovery evidence and explicitly unblock the tool. A batch is not atomic; recovery conflicts preserve files and records for further handling. NAS, iCloud and third-party sync compatibility remain unverified.

### File Info and checksums

Check a download or a shared file against a checksum supplied by its publisher, starting right in Finder. This tool starts off.

1. In **Extensions → File & Folder Tools**, enable the master switch and **File Info**.
2. Select **one ordinary file** in Finder, then choose **File Info…**. Opening the panel shows its name, kind, size, location and dates without calculating.
3. Keep the recommended SHA-256 default, or choose SHA-512, SHA-1, MD5 or all four, then click **Calculate**. All four are calculated in a single read. You can cancel while it runs.
4. Use **Copy result**, or copy all results in All mode. To compare, first select and calculate one algorithm, expand **Compare checksum**, and paste an expected value for that algorithm. The panel distinguishes a match, a mismatch and invalid input.

![File Info window with example text-file metadata, a calculated SHA-256 result and the Compare checksum control](/images/file-info-en.jpg)

<p class="guide-caption">Example SHA-256 result. File contents are read only when calculation is requested. Changing the algorithm requires a new calculation.</p>

Results describe **the file contents read this time**; later changes require recalculation. MD5 and SHA-1 are for legacy compatibility. Checksums are not encryption or proof of origin. Download known cloud placeholders in Finder first. Folders, packages, links, aliases and multiple selections do not show this entry. Detected changes, read failures and cancellation discard results. Closing cancels the read and waits for cleanup.

## Process images and extract text

In the app, open **Extensions → Resource Tools → Use Tools** and choose local images. Finder menu integration is not required. To start from Finder, enable the default-off Resource Tools master switch and the actions you need under **Finder Menu Settings**, then select images and right-click.

![Resource Tools page showing conversion, compression, resizing, icons, stitching and text extraction](/images/resource-tools-en.jpg)

<p class="guide-caption">Use Tools works inside the app; Finder integration is a separate choice.</p>

Convert between JPEG, PNG, HEIC and TIFF; compress or resize; generate icons; stitch at least two images; or extract text with OCR. The processing panel shows a preview and output location before you run an action. Originals stay unchanged and results are saved separately. You can edit OCR text, then explicitly copy it or save a TXT file.

## Toggle Finder hidden items

![FileMint Finder & Folders settings with the hidden-item toggle](/images/finder-hidden-items-en.jpg)

<p class="guide-caption">Example interface. Finder controls the actual hidden-item state.</p>

1. Open **Finder &amp; Folders** in FileMint and find Finder Display; you can also use the FileMint menu-bar command.
2. Click **Toggle** yourself. On first use, FileMint directs you to **System Settings → Privacy &amp; Security → Accessibility** to authorize the app.
3. Return to FileMint and click **Toggle** again. It does not switch automatically when you leave System Settings, and it does not store or guess Finder's current state. If the command is unavailable, use Finder's `⌘⇧.` shortcut.

## Save and find Favorite Locations

![FileMint Favorite Locations manager](/images/favorite-locations-en.jpg)

<p class="guide-caption">Example interface. Favorites include only items you add; folders are not crawled.</p>

1. Open **Extensions → Favorite Locations** and choose **Add Files or Folders…**, or drop items onto the list.
2. In a configured Finder folder, select a file or folder and choose **Add to Favorite Locations** from its context menu. This does not expand Finder's authorized scope.
3. Search saved names, paths or groups; pin items or change groups in batches. Finder shows at most 6 pinned and 4 recently located items, followed by **Search All**.
4. **Locate** opens a folder, or opens a file's parent and selects the file. **Open File** is a separate action.

## Remove private image metadata

![FileMint Resource Tools entry for Remove Private Metadata](/images/remove-private-metadata-en.jpg)

<p class="guide-caption">Example interface. The original stays untouched; the output is a separate `-clean` copy.</p>

Choose local images in **Resource Tools → Use Tools**, or select images in Finder after enabling Resource Tools and choose **Remove Private Metadata**. The Finder menu item starts the job. It removes location, capture-time, camera, IPTC, XMP and other text metadata. Target formats are JPEG, PNG, TIFF and ordinary single-image HEIC when supported by the system. Unsupported files and failed readback checks do not produce a “clean” copy. Re-encoding can change size or color; filenames and information visible in the pixels are not removed.

## Appearance and updates

Under **General → Appearance**, choose Follow System, Light or Dark, plus English, Chinese or the system language. **About** has a manual update check. Automatic checks can be disabled in **General**. See the [installation guide](./install#later-updates) for update installation steps.

**Finder Menu Icons** offers Colored and System Monochrome. Monochrome follows Finder's appearance and menu highlighting; saved colors return when you switch back to Colored. Click the icon button beside a template or supported menu entry to search system symbols, preview an icon, change its colors or reset it. You can still change symbols in monochrome mode while the color controls are disabled. Configured Open with App entries retain their application icons.

## If something is not working

**No New File menu in Finder:** Check the Finder extension status in FileMint and enable its macOS switch if needed. Confirm that you clicked inside the configured menu scope. If the menu has not refreshed after a permission change, relaunch Finder. You can still use **New File…** in the main app.

**The menu appears, but saving asks for access:** Follow FileMint's prompt and select the working folder in the system folder picker. Full Disk Access and FileMint's saved folder authorization are different. The Full Disk Access guide staying visible does not mean its system switch is off.

**An action is missing:** Right-click in the right place: a folder background for creation, selected items for most File & Folder Tools, a selected item or folder background for Copy Paths and Open with App, and supported selected images for Resource Tools. Then check the module switch, action switch and main-menu/submenu placement.

Still stuck? Open a [GitHub issue](https://github.com/FileMintApp/FileMint/issues) with your macOS and FileMint versions, the entry point you used, and the message you saw. Please leave out private file contents and full paths.
