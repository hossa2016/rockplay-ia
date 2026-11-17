import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'playback_ui.dart';

/// Pantalla de video "acompañante": muestra el video de YouTube en silencio
/// (el audio sale del reproductor principal). Primero intenta el reproductor
/// incrustado; si YouTube lo rechaza (error 152/153) o no arranca, carga la
/// versión web móvil y deja visible solo el video.
class VideoView extends StatefulWidget {
  final String videoId;
  const VideoView({super.key, required this.videoId});

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  final PlaybackUi pb = PlaybackUi.instance;
  InAppWebViewController? _c;
  bool _fallback = false;
  bool _ok = false;
  Timer? _watchdog;
  String _status = 'cargando…';
  int _mode = 0;
  static const List<String> _modeNames = [
    'A: híbrido',
    'B: híbrido sin GPU',
    'C: textura',
    'D: textura sin GPU',
  ];
  void _st(String m) {
    if (mounted) setState(() => _status = m);
  }

  static const String _focusJs = r'''
(function(){
  try{
    var css='html,body{background:#000!important;overflow:hidden!important}'
      +'body *{visibility:hidden!important}'
      +'.html5-video-player,.html5-video-player *,#player,#player *,video{visibility:visible!important}'
      +'.html5-video-player,#player-container-id,#player{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:2147483647!important;background:#000!important}'
      +'video{width:100%!important;height:100%!important;object-fit:contain!important;left:0!important;top:0!important}'
      +'.ytp-unmute,.ytp-unmute-inner,[class*="unmute"]{display:none!important}'
      +'.ytp-chrome-bottom,.ytp-chrome-top,.ytp-gradient-top,.ytp-gradient-bottom{display:none!important}';
    var s=document.createElement('style');s.textContent=css;document.head.appendChild(s);
    var v=document.querySelector('video');
    if(v){v.muted=true;v.play();}
  }catch(e){}
})();
''';

  @override
  void initState() {
    super.initState();
    pb.playing.addListener(_sync);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    pb.playing.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final play = pb.playing.value;
    if (_fallback) {
      _c?.evaluateJavascript(
          source:
              "var v=document.querySelector('video'); if(v){v.muted=true; v.${play ? 'play' : 'pause'}();}");
    } else {
      _c?.evaluateJavascript(source: "cmd('${play ? 'playVideo' : 'pauseVideo'}')");
    }
  }

  void _goFallback() {
    if (_fallback || !mounted) return;
    _fallback = true;
    _watchdog?.cancel();
    _st('plan B: página móvil');
    _c?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(
            'https://m.youtube.com/watch?v=${widget.videoId}&t=${pb.position.value.inSeconds}s'),
      ),
    );
  }

  String _html(String id, int start) => '''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
iframe{border:0;width:100%;height:100%}</style></head><body>
<iframe id="p" referrerpolicy="strict-origin-when-cross-origin" src="https://www.youtube.com/embed/$id?autoplay=1&mute=1&controls=0&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https%3A%2F%2Fwww.youtube.com&start=$start" allow="autoplay; encrypted-media" allowfullscreen></iframe>
<script>
function cmd(f){document.getElementById('p').contentWindow.postMessage(JSON.stringify({event:'command',func:f,args:''}),'*');}
var fr=document.getElementById('p');
fr.addEventListener('load',function(){
  fr.contentWindow.postMessage(JSON.stringify({event:'listening',id:1,channel:'widget'}),'*');
});
window.addEventListener('message',function(e){
  try{
    var d=typeof e.data==='string'?JSON.parse(e.data):e.data;
    if(d.event==='onError'){window.flutter_inappwebview.callHandler('ytErr',String(d.info));}
    if(d.event==='onStateChange'&&d.info===1){window.flutter_inappwebview.callHandler('ytOk');}
    if(d.event==='infoDelivery'&&d.info&&d.info.playerState===1){window.flutter_inappwebview.callHandler('ytOk');}
  }catch(_){}
});
</script>
</body></html>''';

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(child: _web()),
          Positioned(
            left: 6,
            bottom: 6,
            child: GestureDetector(
              onTap: () => setState(() {
                _mode = (_mode + 1) % _modeNames.length;
                _fallback = false;
                _ok = false;
                _status = 'cambiando a ${_modeNames[_mode]}…';
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: const Color.fromRGBO(0, 0, 0, 0.7),
                child: Text('$_status · modo ${_modeNames[_mode]} (toca para cambiar)',
                    style:
                        const TextStyle(fontSize: 10, color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _web() {
    return InAppWebView(
        key: ValueKey<String>('${widget.videoId}-$_mode'),
        initialData: InAppWebViewInitialData(
          data: _html(widget.videoId, pb.position.value.inSeconds),
          baseUrl: WebUri('https://www.youtube.com'),
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          useHybridComposition: _mode < 2,
          hardwareAcceleration: _mode % 2 == 0,
          transparentBackground: false,
          supportZoom: false,
        ),
        onWebViewCreated: (c) {
          _c = c;
          c.addJavaScriptHandler(
              handlerName: 'ytErr',
              callback: (args) {
                _st('error YouTube ${args.isNotEmpty ? args.first : ''}');
                _goFallback();
              });
          c.addJavaScriptHandler(
              handlerName: 'ytOk',
              callback: (args) {
                _ok = true;
                _watchdog?.cancel();
                _st('reproductor incrustado OK');
              });
          // Si en 7 s no arrancó el reproductor incrustado: plan B.
          _watchdog = Timer(const Duration(seconds: 7), () {
            if (!_ok) _goFallback();
          });
        },
        onLoadStop: (c, url) {
          if (_fallback) {
            _st('plan B cargado: ${url?.host ?? ''}');
            c.evaluateJavascript(source: _focusJs);
            Future<void>.delayed(const Duration(seconds: 2), () {
              if (mounted) c.evaluateJavascript(source: _focusJs);
            });
          }
          _sync();
        },
      );
  }
}
