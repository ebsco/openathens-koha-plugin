(function(){

var initOA = setInterval(function(){
    try{
        jQuery().jquery;
        clearInterval(initOA);
        startOAAuth();
    }
    catch(err)
    {}
},10);

function startOAAuth(){
    if (jQuery('body').data('oaAuth') == 1) { return;}
    if (jQuery('#oaresponse').val() != "")
    {
         console.log('Begin authentication');
         var userid = jQuery('#oaresponse').val();
         var location = encodeURIComponent(window.location.href);
         jQuery.getJSON('/plugin/Koha/Plugin/OAKoha/OAKoha.pl?q=' + userid + '&l=' + location,function(data){BeginOASession(data)});
    }
    //Call to fetch jsSHA, if needed in future
    /*jQuery.ajax({
         url: 'https://cdnjs.cloudflare.com/ajax/libs/jsSHA/2.2.0/sha_dev.js',
         dataType:'script',
         async:false,
         success: function(){
            checkAPI();
         }
    });*/
    return;
}

function BeginOASession(data)
{
     console.log(data['oaResponse']);
     if (data['oaResponse'] == 'Success')
     {
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
     }
     return;
}

//Keeping API code commented in case it can be successfully run and is required in the future
/*
function checkAPI(){
    var apiKey = "";
    var httpVerb = "get";
    var apiUserId = 'koha_library';
    var date = new Date();
    var mykohaUrl = window.location.hostname;

    var shaObj = new jsSHA("SHA-256","TEXT");
    shaObj.setHMACKey(apiKey, "TEXT");
    var message = httpVerb.toUpperCase() + " " + apiUserId + " " + date;
    shaObj.update(message);
    var authHeader = "Koha " + apiUserId + ":" + shaObj.getHMAC("HEX");

    jQuery.ajax({
        type: 'GET',
        dataType: 'json',
        headers: {
            "Authorization" : authHeader,
            "X-Koha-Date": date
        },
        url: mykohaUrl + "/v1/borrowers/",
        success: function(data){
            console.log(data);
        }
    });
}
*/
}());
