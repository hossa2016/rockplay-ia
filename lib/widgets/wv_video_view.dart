import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'playback_ui.dart';

/// Video "acompañante" con webview_flutter (en silencio; el audio sale del
/// reproductor principal). Cuatro modos que se cambian tocando la etiqueta:
/// 0 incrustado+textura, 1 incrustado+híbrido, 2 página móvil+textura,
/// 3 página móvil+híbrido.
class WvVideoView extends StatefulWidget {
  final String videoId;
  const WvVideoView({super.key, required this.videoId});

  @override
  State<WvVideoView> createState() => _WvVideoViewState();
}

class _WvVideoViewState extends State<WvVideoView> {
  final PlaybackUi pb = PlaybackUi.instance;
  WebViewController? _c;
  int _mode = 0;
  String _status = 'cargando…';
  static const _names = [
    '1: incrustado/textura',
    '2: incrustado/híbrido',
    '3: móvil/textura',
    '4: móvil/híbrido',
  ];

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
    _build();
  }

  @override
  void didUpdateWidget(covariant WvVideoView old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) _build();
  }

  @override
  void dispose() {
    pb.playing.removeListener(_sync);
    super.dispose();
  }

  void _st(String m) {
    if (mounted) setState(() => _status = m);
  }

  bool get _mobilePage => _mode >= 2;
  bool get _hybrid => _mode.isOdd;

  void _sync() {
    final play = pb.playing.value;
    final c = _c;
    if (c == null) return;
    if (_mobilePage) {
      c.runJavaScript(
          "var v=document.querySelector('video'); if(v){v.muted=true; v.${play ? 'play' : 'pause'}();}");
    } else {
      c.runJavaScript("cmd('${play ? 'playVideo' : 'pauseVideo'}')");
    }
  }

  String _html(String id, int start) => '''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
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
    if(d.event==='onError'){Yt.postMessage('err:'+d.info);}
    if(d.event==='infoDelivery'&&d.info&&d.info.playerState===1){Yt.postMessage('ok');}
  }catch(_){}
});
</script>
</body></html>''';

  void _build() {
    final c = WebViewController.fromPlatformCreationParams(
        const PlatformWebViewControllerCreationParams())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('Yt', onMessageReceived: (m) {
        if (m.message == 'ok') {
          _st('reproduciendo OK');
        } else if (m.message.startsWith('err:')) {
          _st('error YouTube ${m.message.substring(4)}');
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          if (_mobilePage) {
            _st('página móvil cargada');
            c0?.runJavaScript(_focusJs);
            Future<void>.delayed(const Duration(seconds: 2), () {
              if (mounted) c0?.runJavaScript(_focusJs);
            });
          }
          _sync();
        },
      ));
    c0 = c;
    final p = c.platform;
    if (p is AndroidWebViewController) {
      p.setMediaPlaybackRequiresUserGesture(false);
    }
    final start = pb.position.value.inSeconds;
    if (_mobilePage) {
      c.loadRequest(Uri.parse(
          'https://m.youtube.com/watch?v=${widget.videoId}&t=${start}s'));
    } else {
      c.loadHtmlString(_html(widget.videoId, start),
          baseUrl: 'https://www.youtube.com');
    }
    _c = c;
  }

  WebViewController? c0;

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: c == null
                ? const ColoredBox(color: Colors.black)
                : WebViewWidget.fromPlatformCreationParams(
                    key: ValueKey<String>('${widget.videoId}-$_mode'),
                    params: AndroidWebViewWidgetCreationParams(
                      controller: c.platform,
                      displayWithHybridComposition: _hybrid,
                    ),
                  ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _mode = (_mode + 1) % _names.length;
                  _status = 'cambiando…';
                });
                _build();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: const Color.fromRGBO(0, 0, 0, 0.7),
                child: Text('$_status · ${_names[_mode]} (toca)',
                    style:
                        const TextStyle(fontSize: 10, color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
