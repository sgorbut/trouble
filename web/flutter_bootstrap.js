{{flutter_js}}
{{flutter_build_config}}

// Загрузка без устаревшего service worker Flutter: офлайн-режим даёт свой web/sw.js
// (регистрируется в index.html). Иначе заглушка Flutter вытесняет его и удаляет себя.
_flutter.loader.load();
