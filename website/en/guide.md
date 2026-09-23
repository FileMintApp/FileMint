---
title: FileMint User Guide
description: Learn FileMint step by step, from Finder setup and file creation to templates, image tools and optional actions.
pageClass: guide-page
---

# FileMint User Guide

Start by creating one file in Finder, then turn on the other features as you need them. If FileMint is not installed yet, follow the [installation guide](./install). Screenshots show example files, apps and settings; your initial setup may differ.

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

**Keyboard:** Use Tab / Shift-Tab to move between controls, ⌘↩ to create, and Esc to cancel. Return inserts a newline in the content editor. The Paste button reads clipboard text only when you click it.

## Save reusable templates

Open **Templates & Types**, enable and reorder the formats you use. Click **New Text Template…** to add a template name, default filename and starter content. You can keep several templates for one suffix and choose a default. Select the template later from Finder or the creation panel.

![Templates and Types settings with New Text Template, Import Document Template and the format list](/images/file-types-en.jpg)

<p class="guide-caption">Enabled formats appear in Finder's quick creation menu.</p>

To reuse an existing Word or Excel document, click **Import Document Template…** and select a `.docx` or `.xlsx`. FileMint keeps an independent local copy. Choosing that template creates a new document with the original formatting and content; it does not change the source. An existing output name is numbered automatically.

## Save a clipboard image as PNG

1. Copy a screenshot or bitmap image.
2. Choose **Paste Image as File…** from the FileMint sidebar or Finder's **New File** menu.
3. Check the preview, filename and destination, then click **Create**.

FileMint reads the image only when you choose this action. Cancelling creates nothing. This action saves PNG and numbers an existing filename automatically.

## Open selected items with your apps

Open **Extensions → Open with App**, click **Add App**, choose a local application, and place it in Finder's main menu or the **Open with App** submenu. Then select a file or folder in a configured Finder location, right-click it and choose the app.

![Open with App settings showing configured applications and individual menu positions](/images/open-with-en.jpg)

<p class="guide-caption">These applications are an example. A new installation starts with an empty list.</p>

This does not change macOS default file associations. The chosen app decides which file types it can open. If an app is missing from the menu, check that it is still installed at its configured location and that the selection is within the menu scope.

## Enable File & Folder Tools when needed

Open **Extensions → File & Folder Tools**, enable the master switch, then enable the actions you want. Each action can appear in Finder's main menu or the **File & Folder Tools** submenu. The master switch starts off.

![File and Folder Tools settings showing action switches and menu placement controls](/images/file-tools-en.jpg)

<p class="guide-caption">This is an example with tools enabled. Check the Permanent Delete setting before using it.</p>

- **Copy Names / Paths:** Select one or more items, then use the context menu. Multiple items are copied one per line.
- **Move File / Folder:** Select the source items and choose this action. Then right-click the **background of the destination folder** and choose **Move Selected Items Here**. The first step only remembers the sources; existing names are never overwritten or merged.
- **Delete Permanently:** Bypasses Trash and asks for confirmation by default. It cannot be undone. Enable it only when you need it.
- **AirDrop / Send Alias to Desktop:** AirDrop opens the native macOS chooser so you select a recipient. An alias points to the original item without moving it.

## Process images and extract text

In the app, open **Extensions → Resource Tools → Use Tools** and choose local images. Finder menu integration is not required. To start from Finder, enable the default-off Resource Tools master switch and the actions you need under **Finder Menu Settings**, then select images and right-click.

![Resource Tools page showing conversion, compression, resizing, icons, stitching and text extraction](/images/resource-tools-en.jpg)

<p class="guide-caption">Use Tools works inside the app; Finder integration is a separate choice.</p>

Convert between JPEG, PNG, HEIC and TIFF; compress or resize; generate icons; stitch at least two images; or extract text with OCR. The processing panel shows a preview and output location before you run an action. Originals stay unchanged and results are saved separately. You can edit OCR text, then explicitly copy it or save a TXT file.

## Appearance and updates

Under **General → Appearance**, choose Follow System, Light or Dark, plus English, Chinese or the system language. **About** has a manual update check. Automatic checks can be disabled in **General**. See the [installation guide](./install#later-updates) for update installation steps.

## If something is not working

**No New File menu in Finder:** Check the Finder extension status in FileMint and enable its macOS switch if needed. Confirm that you clicked inside the configured menu scope. If the menu has not refreshed after a permission change, relaunch Finder. You can still use **New File…** in the main app.

**The menu appears, but saving asks for access:** Follow FileMint's prompt and select the working folder in the system folder picker. Full Disk Access and FileMint's saved folder authorization are different. The Full Disk Access guide staying visible does not mean its system switch is off.

**An action is missing:** Right-click in the right place: a folder background for creation, selected items for File & Folder Tools and Open with App, and supported selected images for Resource Tools. Then check the module switch, action switch and main-menu/submenu placement.

Still stuck? Open a [GitHub issue](https://github.com/FileMintApp/FileMint/issues) with your macOS and FileMint versions, the entry point you used, and the message you saw. Please leave out private file contents and full paths.
