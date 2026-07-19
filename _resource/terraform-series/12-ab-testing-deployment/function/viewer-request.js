exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request;
  const headers = request.headers;

  // If the routing cookie already exists, forward the request as-is.
  if (headers.cookie) {
    for (let i = 0; i < headers.cookie.length; i++) {
      if (headers.cookie[i].value.indexOf("X-Redirect-Flag") >= 0) {
        callback(null, request);
        return;
      }
    }
  }

  // Otherwise assign 60% of new visitors to Pro and 40% to Pre-Pro.
  const cookie =
    Math.random() < 0.6 ? "X-Redirect-Flag=Pro" : "X-Redirect-Flag=Pre-Pro";
  headers.cookie = headers.cookie || [];
  headers.cookie.push({ key: "Cookie", value: cookie });

  callback(null, request);
};
