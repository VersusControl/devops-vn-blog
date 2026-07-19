exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request;
  const requestHeaders = request.headers;
  const response = event.Records[0].cf.response;

  if (requestHeaders.cookie) {
    for (let i = 0; i < requestHeaders.cookie.length; i++) {
      if (requestHeaders.cookie[i].value.indexOf("X-Redirect-Flag=Pro") >= 0) {
        response.headers["set-cookie"] = [
          { key: "Set-Cookie", value: `X-Redirect-Flag=Pro; Path=/` },
        ];
        callback(null, response);
        return;
      }

      if (
        requestHeaders.cookie[i].value.indexOf("X-Redirect-Flag=Pre-Pro") >= 0
      ) {
        response.headers["set-cookie"] = [
          { key: "Set-Cookie", value: `X-Redirect-Flag=Pre-Pro; Path=/` },
        ];
        callback(null, response);
        return;
      }
    }
  }

  callback(null, response);
};
