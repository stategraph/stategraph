// js_content handler for the GitHub webhook location. An event whose account
// login equals $events_owner, compared without case, goes to @terrat. Every
// other event gets a 503. An empty $events_owner or a body that is not JSON
// also writes a warn line to the error log.

function login(r) {
  let event;
  try {
    event = JSON.parse(r.requestText);
  } catch (e) {
    r.warn('events.filter: request body is not JSON; the GitHub App webhook content type must be application/json');
    return null;
  }
  const account = ((event || {}).repository || {}).owner || ((event || {}).installation || {}).account || {};
  return String(account.login).toLowerCase();
}

function filter(r) {
  const owner = (r.variables.events_owner || '').toLowerCase();
  if (!owner) {
    r.warn('events.filter: $events_owner is empty; every webhook gets a 503');
  } else if (login(r) === owner) {
    r.internalRedirect('@terrat');
    return;
  }
  r.headersOut['Content-Type'] = 'text/plain; charset=utf-8';
  r.return(503, 'Service temporarily unavailable for scheduled maintenance. Please try again later.\n');
}

export default { filter };
