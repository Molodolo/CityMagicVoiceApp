let wakeLock = null;

async function requestWakeLock() {
  try {
    wakeLock = await navigator.wakeLock.request('screen');
    wakeLock.addEventListener('release', () => {
      console.log('Wake Lock was released');
    });
    console.log('Wake Lock is active');
  } catch (err) {
    console.error(`${err.name}, ${err.message}`);
  }
}

async function checkForRedirect() {
  const response = await fetch('/check');
  const data = await response.json();
  if (data.redirect) {
    window.location.href = data.url;
  } else {
    setTimeout(checkForRedirect, 1000); // Check again in 1 second
  }
}

window.onload = () => {
  checkForRedirect();
  if ('wakeLock' in navigator) {
    requestWakeLock();
  } else {
    console.warn('Wake Lock API not supported in this browser');
  }
};
