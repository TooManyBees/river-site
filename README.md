# Netlify + Dropbox client site

Based almost completely on jimniels's [netlibox](https://github.com/jimniels/netlibox/) template, with modifications:

* lambda function verifies the Dropbox signature before triggering build (were we... were we just gonna go on honor system here???)
* no NPM needed
    * the lambda function, is valid Node 8 LTS
    * fetching dropbox content is done in ruby, since we're using it for Jekyll anyway
    * thank heavens
* files that are have an html or markdown extension are added as posts, while other files are added as static assets. The list of extension of files that count as posts can be changed in [dropbox.rb](/dropbox.rb) with the constant `POST_EXTNAMES`

# Setup

Firstly, there is nothing special happening in `./app`. It contains a Jekyll new site boilerplate, with the exception of `_config.yml`, `Gemfile`, and `Gemfile.lock` that remain in the top level directory.

The only change of consequence in `_config.yml` is the line
```yaml
source: "./app"
```

In Dropbox:

1. https://www.dropbox.com/developers/apps → **Create App**
2. Pick Dropbox API, limit to App Folder
3. **App secret** → **Show**, save for later as `DROPBOX_APP_SECRET`
4. **OAuth2** → **Allow Implicit Grants** → **Disallow**
5. **OAuth2** → **Generate access token**, save for later as `DROPBOX_ACCESS_TOKEN`

In source code:

1. Consider renaming `functions/dropbox-webhook.js` because Netlify will mount it at a predictable path based on its file name, and that would allow someone to maliciously use up your monthly Function quota.

In Netlify:

1. Create a Git-based app (otherwise it will not support build hooks)
2. Go to (on top nav) **Settings** → **Build & Deploy** → **Continuous Deployment**
3. **Build hooks** → **Add Build Hook**, name it anything (`dropbox-webhook` is good), save generated url for later as `NETLIFY_BUILD_HOOK_URL`
4. In **Build environment variables** → **Edit variables**, create these variables with the values saved from earlier
    1. `DROPBOX_APP_SECRET`
    2. `DROPBOX_ACCESS_TOKEN`
    3. `NETLIFY_BUILD_HOOK_URL`
5. Go to (on top nav) **Functions**. It may take a while to populate the list of functions after initial deploy.
6. Go to function `dropbox-webhook.js` (unless you renamed it), copy the **Endpoint** url, save for later

Back in Dropbox app settings:

1. **Webhooks** → **Add**, with the function url you just saved. Its status should quickly change to *Enabled*. If not, look in the Netlify function log (on the page that lists its URL) and check if the function is being invoked at all. It should look like:
    ```
    8:07:43 AM: dropbox-webhook invoked
    8:07:43 AM: Echoing challenge 2_mLAgJwloCKup6nTktFXFA131c2ycyJmjtzd_Rc9HY
    ```
