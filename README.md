# Gemini AI Metadata Tagger for Adobe Lightroom Classic

An Adobe Lightroom Classic plugin that uses **Google Gemini AI** vision models to automatically analyze your photographs and generate commercial-ready **Titles**, **Captions**, and **Keywords**.

## Features

* **Automated Stock & Catalog Metadata:** Generates a concise commercial title (5–10 words), a natural scene description (15–30 words), and relevance-ranked keywords.
* **Smart Keyword Top-Up:** Counts existing keywords already assigned to a photo and generates only the exact number of new, non-duplicate tags needed to reach your target limit (up to 50 keywords total).
* **Context-Aware Title & Caption Refinement:** If a photo already has initial notes in the *Title* or *Caption* fields (such as locations, landmarks, or event names), Gemini uses that text as factual context and expands it with visual details from the image.
* **Free Tier & Paid Model Support:** Includes a dropdown selector for free-tier Gemini models (`gemini-3.5-flash-lite`, `gemini-3.8-flash`, `gemini-3.6-flash`, `gemini-3.1-flash-lite`), paid Gemini 4 models, custom model ID input, and a built-in **Auto-Detect Free Model** button.
* **Fast & Lightweight:** Sends a 1024px JPEG preview directly from Lightroom's cache—no manual RAW export required.
* **Multi-Language Output:** Supports English (standard stock photography metadata) and Bosnian / Croatian / Serbian.

---

## Requirements

* **Adobe Lightroom Classic** (SDK 6.0 or newer; does not support cloud-based Lightroom CC or Photoshop)
* A free or paid **Google Gemini API Key** from [Google AI Studio](https://aistudio.google.com/)

---

## Installation

1. Download or clone this repository and ensure the folder **`GeminiTagger.lrplugin`** contains:
   * `Info.lua`
   * `PluginInit.lua`
   * `GeminiSettings.lua`
   * `TagPhotos.lua`
2. Open **Adobe Lightroom Classic**.
3. Go to **File > Plug-in Manager...**
4. Click **Add** in the bottom-left corner, select the **`GeminiTagger.lrplugin`** folder, and click **Select Folder**.

---

## Configuration

1. In **File > Plug-in Manager...**, select **Gemini AI Metadata Tagger**.
2. Under **Google Gemini AI Settings**, paste your **Gemini API Key**.
3. Choose a model from **Select Gemini Model** (for free-tier usage, **`[Free Tier] Gemini 3.5 Flash-Lite`** offers the highest daily quota, while **`[Free Tier] Gemini 3.8 Flash`** provides the highest free quality) or click **Auto-Detect Free Model**.
4. Set your preferred **Output Language** and **Max Keywords** (5–50).
5. Click **Done**.

---

## Usage

1. Switch to the **Library** module in Lightroom Classic and select one or more photos.
2. *(Optional)* Add any specific location names or notes into the *Title* or *Caption* fields, or add core keywords you want to keep.
3. In the top menu bar, go to **Library > Plug-in Extras > Generate Title, Caption & Keywords (Gemini AI)**.
4. Wait for the progress bar to finish—your photo's **Title**, **Caption**, and **Keyword Tags** will automatically populate in the right-hand Metadata panel.

---

## Author

* **Vedad Ceric** © 2026
* GitHub: [https://github.com/vedadceric](https://github.com/vedadceric)
* Contact: [vedadc2@gmail.com](mailto:vedadc2@gmail.com)

## License

This project is open-source and available under the [MIT License](LICENSE).
