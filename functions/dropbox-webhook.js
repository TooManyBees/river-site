/* This is executed in Node 8 LTS by default
 * https://nodejs.org/docs/latest-v8.x/api/index.html
 *
 * Let's keep requires limited to node's stdlib for simplicity.
 */

var url = require('url');
var https = require('https');
var crypto = require('crypto');

exports.handler = function(event, context, callback) {
  /* Dropbox requires an initial verification before it will send
   * traffic. Just echo the challenge query param back at it.
   */
  var challenge = event.queryStringParameters.challenge;
  if (challenge) {
    console.log("Echoing challenge " + challenge);
    callback(null, {
      statusCode: 200,
      body: challenge,
      headers: {
        'Content-Type': 'text/plain',
        'X-Content-Type-Options': 'nosniff',
      },
    });
    return;
  }

  if (!process.env.DROPBOX_APP_SECRET) {
    console.log("function env misconfigured, missing dropbox app secret key");
    callback(null, {
      statusCode: 500,
      body: "function env is misconfigured: missing secret key",
    });
    return;
  }

  /* Ensure that the request is really from Dropbox. The request
   * is signed a sha256 hash of the request body, using our app's
   * secret key.
   */
  var signature = event.headers['x-dropbox-signature'];
  if (signature) {
    var hash = crypto.createHmac('sha256', process.env.DROPBOX_APP_SECRET).update(event.body).digest('hex');
    if (signature !== hash) {
      console.log("X-Dropbox-Signature does not match hashed request body ("+signature+" != "+hash+")");
      callback(null, {
        statusCode: 403,
        body: "invalid signature",
      });
      return;
    }

    var buildHookUrl;
    try {
      buildHookUrl = url.parse(process.env.NETLIFY_BUILD_HOOK_URL);
    } catch(e) {
      console.log("function env is misconfigured, couldn't parse build hook url");
      callback(null, {
        statusCode: 500,
        body: "function env is misconfigured: bad/missing build hook url"
      });
    }

    /* Make the request to the real build hook endpoint.
     * Just return the status code we get back.
     */
    console.log("receiving dropbox build request");
    https.request({
      method: 'POST',
      hostname: buildHookUrl.hostname,
      path: buildHookUrl.path,
    }, function(res) {
        res.on('end', function() {
          console.log("build hook sent with status code " + res.statusCode);
          callback(null, {
            statusCode: res.statusCode,
            body: '',
          });
        });
        res.resume(); // throw away the body, it's fine
      }
    ).on('error', function(e) {
      console.log("build hook request errored", e);
      callback(null, {
        statusCode: 502,
        body: e.toString(),
      });
    }).end();
  } else {
    callback(null, {
      statusCode: 400,
      body: "",
    });
  }
}
