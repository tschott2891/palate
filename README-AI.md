# Palate Intelligence setup

The iOS app calls a secure server endpoint for AI beverage profiles and opt-in label enrichment. It never contains an OpenAI API key.

## Deploy the endpoint

The `api/palate.mjs` file is a Vercel serverless function. Import this repository into Vercel, then configure these server-side environment variables:

- `OPENAI_API_KEY` — secret OpenAI API key.
- `PALATE_MODEL` — optional model override. The endpoint defaults to `gpt-6-luna`.

Deploy the project and copy the public URL for `/api/palate`.

## Connect the iOS app

In the Palate Xcode target, add a String entry to the generated Info.plist build settings:

```
PALATE_INTELLIGENCE_URL = https://your-deployment.vercel.app/api/palate
```

Use a different endpoint per build configuration (for example, development and production). The app shows a clear unavailable state until this URL is supplied.

## Privacy

When a user taps **Ask Palate**, the app sends the selected item's saved fields, up to eight relevant tasting records, and its optional label image to this endpoint. Only include history that belongs to the item currently being viewed.

When a user taps **Enhance with Palate** during label review, the app sends only that label image and its on-device OCR text. The suggested fields remain editable and are never applied automatically.
