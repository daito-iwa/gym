// キャッシュバスティング - AI強化・並び替え・グループ表示機能バージョン v1.5.1
console.log('キャッシュクリア実行中...');
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function(registrations) {
    for(let registration of registrations) {
      registration.unregister();
    }
  });
}
if ('caches' in window) {
  caches.keys().then(function(names) {
    for(let name of names) {
      caches.delete(name);
    }
  });
}
window.location.reload(true);