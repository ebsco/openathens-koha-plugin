///*oa{*/var oas=document.createElement( 'script' );oas.type = 'text/javascript';oas.src='/plugin/Koha/Plugin/OAKoha/OAKoha.js';document.body.appendChild(oas);/*}oa*/

//console.log('oaV1');

initOA=0;
(function(){

    var jqForOA = setInterval(function () { if (window.jQuery) { clearInterval(jqForOA); startOAAuth(); } }, 10);

function startOAAuth(){
	if (initOA === 1) { return; } else { initOA = 1; }

    if (jQuery('.loggedinusername').text().replace(/ /g,'') != ""){
		if(Cookies.get('oasession')!==undefined){
			console.log('authenticated');
			return;
		}
		
         console.log('Begin authentication');
         var location = encodeURIComponent(window.location.href);
         jQuery.getJSON('/plugin/Koha/Plugin/OAKoha/OAKoha.pl?l=' + location,function(data){BeginOASession(data)});
		jQuery('.breadcrumb').before('<div id="oaTag" style="padding:15px;background-color:#5d3260;color:#FFF;font-weight:bold;">Authenticating into OpenAthens. Please wait...<div>');
    }else{
		Cookies.remove('oasession');
	}
}

	function BeginOASession(data){
		 console.log(data['oaResponse']);
		 if (data['oaResponse'] == 'Success')
		 {
			 Cookies.set('oasession', '1');
                         window.location = data['sessionUrl'];
		 }
		 else
		 {
			 if (typeof data['data'] != 'undefined')
			 {
				  console.log(data['data']);
			 }
			  if (typeof data['error'] != 'undefined')
			 {
				  console.log(data['error']);
			 }
			 //display error message if authentication fails
			 jQuery('#oaTag').html("Open Athens Authentication failed. Please contact your administrator if you are authorised.");
		 }
		 return;
	}
}());


// https://github.com/js-cookie/js-cookie
!function (e) { var n = !1; if ("function" == typeof define && define.amd && (define(e), n = !0), "object" == typeof exports && (module.exports = e(), n = !0), !n) { var o = window.Cookies, t = window.Cookies = e(); t.noConflict = function () { return window.Cookies = o, t } } }(function () { function e() { for (var e = 0, n = {}; e < arguments.length; e++) { var o = arguments[e]; for (var t in o) n[t] = o[t] } return n } function n(o) { function t(n, r, i) { var c; if ("undefined" != typeof document) { if (arguments.length > 1) { if (i = e({ path: "/" }, t.defaults, i), "number" == typeof i.expires) { var a = new Date; a.setMilliseconds(a.getMilliseconds() + 864e5 * i.expires), i.expires = a } try { c = JSON.stringify(r), /^[\{\[]/.test(c) && (r = c) } catch (e) { } return r = o.write ? o.write(r, n) : encodeURIComponent(String(r)).replace(/%(23|24|26|2B|3A|3C|3E|3D|2F|3F|40|5B|5D|5E|60|7B|7D|7C)/g, decodeURIComponent), n = encodeURIComponent(String(n)), n = n.replace(/%(23|24|26|2B|5E|60|7C)/g, decodeURIComponent), n = n.replace(/[\(\)]/g, escape), document.cookie = [n, "=", r, i.expires ? "; expires=" + i.expires.toUTCString() : "", i.path ? "; path=" + i.path : "", i.domain ? "; domain=" + i.domain : "", i.secure ? "; secure" : ""].join("") } n || (c = {}); for (var p = document.cookie ? document.cookie.split("; ") : [], s = /(%[0-9A-Z]{2})+/g, d = 0; d < p.length; d++) { var f = p[d].split("="), u = f.slice(1).join("="); '"' === u.charAt(0) && (u = u.slice(1, -1)); try { var l = f[0].replace(s, decodeURIComponent); if (u = o.read ? o.read(u, l) : o(u, l) || u.replace(s, decodeURIComponent), this.json) try { u = JSON.parse(u) } catch (e) { } if (n === l) { c = u; break } n || (c[l] = u) } catch (e) { } } return c } } return t.set = t, t.get = function (e) { return t.call(t, e) }, t.getJSON = function () { return t.apply({ json: !0 }, [].slice.call(arguments)) }, t.defaults = {}, t.remove = function (n, o) { t(n, "", e(o, { expires: -1 })) }, t.withConverter = n, t } return n(function () { }) });
//# sourceMappingURL=js.cookie.min.js.map
