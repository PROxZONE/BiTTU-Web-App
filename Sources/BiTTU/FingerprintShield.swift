import Foundation
import WebKit

/// Fingerprint-protection injection (Brave-style farbling).
enum FingerprintShield {
    static let scriptIdentifier = "bittu-fingerprint-shield"

    static let source = """
    (function () {
        if (window.__bittuFingerprintShield) return;
        window.__bittuFingerprintShield = true;

        // Per-site seed: same site -> same noise, different sites -> different
        // noise (first-party farbling), stable within a session, useless for
        // cross-site tracking.
        var seed = 0;
        try {
            var parts = location.hostname.split('.');
            var base = parts.slice(-2).join('.') || location.hostname;
            for (var i = 0; i < base.length; i++) {
                seed = (seed * 31 + base.charCodeAt(i)) >>> 0;
            }
        } catch (e) { seed = 0x9e3779b9; }
        function prng() {
            seed = (seed + 0x6D2B79F5) >>> 0;
            var t = seed;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        }

        // --- Canvas farbling: tiny deterministic noise in every readback. ---
        function farbleCanvas(context) {
            ['getImageData', 'toDataURL', 'toBlob'].forEach(function (name) {
                var original = context[name];
                if (typeof original !== 'function' || original.__bittuFarbled) return;
                var farbled = function () {
                    var result = original.apply(this, arguments);
                    try {
                        if (this.canvas) {
                            var w = this.canvas.width, h = this.canvas.height;
                            if (w > 0 && h > 0) {
                                var ctx = this;
                                var sx = Math.floor(prng() * w);
                                var sy = Math.floor(prng() * h);
                                var pixel = ctx.getImageData(sx, sy, 1, 1);
                                pixel.data[0] = (pixel.data[0] ^ (prng() * 2 | 0)) & 0xff;
                                ctx.putImageData(pixel, sx, sy);
                            }
                        }
                    } catch (e) { /* leave result untouched */ }
                    return result;
                };
                farbled.__bittuFarbled = true;
                context[name] = farbled;
            });
        }
        try {
            var proto = HTMLCanvasElement.prototype;
            var origGetContext = proto.getContext;
            proto.getContext = function () {
                var ctx = origGetContext.apply(this, arguments);
                if (ctx) farbleCanvas(ctx);
                return ctx;
            };
            farbleCanvas(CanvasRenderingContext2D.prototype);
            if (typeof OffscreenCanvasRenderingContext2D !== 'undefined') {
                farbleCanvas(OffscreenCanvasRenderingContext2D.prototype);
            }
        } catch (e) {}

        // --- WebGL vendor/renderer: neutral strings. ---
        try {
            var patchGL = function (proto) {
                if (!proto) return;
                var origGetParameter = proto.getParameter;
                if (typeof origGetParameter === 'function') {
                    proto.getParameter = function (param) {
                        // UNMASKED_VENDOR_WEBGL / UNMASKED_RENDERER_WEBGL
                        if (param === 0x9245 || param === 0x9246) {
                            return param === 0x9245 ? 'Apple Inc.' : 'Apple GPU';
                        }
                        return origGetParameter.apply(this, arguments);
                    };
                }
            };
            if (typeof WebGLRenderingContext !== 'undefined') patchGL(WebGLRenderingContext.prototype);
            if (typeof WebGL2RenderingContext !== 'undefined') patchGL(WebGL2RenderingContext.prototype);
        } catch (e) {}

        // --- Hardware probes: neutral, common values. ---
        try {
            var define = function (obj, name, value) {
                Object.defineProperty(obj, name, { value: value, configurable: true, enumerable: true });
            };
            if (navigator.hardwareConcurrency !== undefined) define(navigator, 'hardwareConcurrency', 8);
            if (navigator.deviceMemory !== undefined) define(navigator, 'deviceMemory', 8);
            if (navigator.maxTouchPoints !== undefined) define(navigator, 'maxTouchPoints', 0);
            define(navigator, 'plugins', []);
            define(navigator, 'mimeTypes', []);
            if (navigator.getBattery) navigator.getBattery = function () {
                return Promise.resolve({ charging: true, chargingTime: 0, dischargingTime: Infinity,
                                         level: 1, addEventListener: function () {},
                                         removeEventListener: function () {} });
            };
        } catch (e) {}

        // --- Screen: coarsen to the common 1x tier of the class. ---
        try {
            var coarse = function (n) { return Math.round(n / 240) * 240; };
            Object.defineProperty(screen, 'width',    { value: coarse(screen.width) || 1440, configurable: true });
            Object.defineProperty(screen, 'height',   { value: coarse(screen.height) || 900,  configurable: true });
            Object.defineProperty(screen, 'availWidth', { value: coarse(screen.availWidth) || 1440, configurable: true });
            Object.defineProperty(screen, 'availHeight', { value: coarse(screen.availHeight) || 830, configurable: true });
            Object.defineProperty(screen, 'colorDepth', { value: 24, configurable: true });
            Object.defineProperty(screen, 'pixelDepth', { value: 24, configurable: true });
        } catch (e) {}

        // --- Audio context: per-site noise on sample readouts. ---
        try {
            if (typeof AudioBuffer !== 'undefined' && AudioBuffer.prototype) {
                var origChannel = AudioBuffer.prototype.getChannelData;
                if (origChannel) {
                    AudioBuffer.prototype.getChannelData = function () {
                        var data = origChannel.apply(this, arguments);
                        if (data && data.length) {
                            for (var i = 0; i < Math.min(data.length, 4500); i++) {
                                data[i] = data[i] + (prng() - 0.5) * 1e-7;
                            }
                        }
                        return data;
                    };
                }
            }
        } catch (e) {}
    })();
    """

    /// Injects the shield into a tab configuration at document start.
    static func install(into config: WKWebViewConfiguration) {
        let script = WKUserScript(source: source,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
    }
}