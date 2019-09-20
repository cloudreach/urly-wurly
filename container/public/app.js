(function (init) {
        init(window.jQuery, window, document);

    }(function ($, window, document) {

        // define html elements
            
            $WEB_URL = window.location.hostname,
            $login_urly_wurly = $('#login-urly-wurly'),
            $logout_urly_wurly = $('#logout-urly-wurly'),
            $message_block = $('#message-block'),
            $message = $('#message'),
            $urly_wurly = $('#urly-wurly')

        ;

        $login_urly_wurly.show();
        // register global function for single sign
        window.onSignIn = function (googleUser) {
            $logout_urly_wurly.show();
            var id_token = googleUser.getAuthResponse().id_token;
            show_message('info', 'Authorizing Google client');
            get_sts_credentials(id_token);
        };
        window.signOut = function () {
            var auth2 = gapi.auth2.getAuthInstance();
            auth2.signOut().then(function () {
                console.log('User signed out.');
                location.reload();
            });
        };

        var show_message = function(level, text) {
            let className;
            switch(level.toLowerCase()) {
                case 'error':
                case 'info':
                    className = `text-${level.toLowerCase()}`;
                    break;
                default:
                    className = 'text-info';
            }
            $message.attr('class', className);
            $message.text(text);
            $message_block.show();
        }

        function get_sts_credentials(id_token) {
            // ok we are logged in
            $login_urly_wurly.hide();
            $logout_urly_wurly.show();
            // get STS credentials
            request.post({
                url: `https://${$WEB_URL}/api/get_creds`,
                headers: {
                    "Content-Type": "application/json"
                },
                json: true,
                body: {id_token: id_token}
            }, function (error, response, body) {
                // console.log('Received STS response', body);
                if (body.error || (body.status && body.status.toLowerCase() == 'error')) {
                    console.log('not authorized');
                    $urly_wurly.hide();
                    show_message('error', 'Not Authorized');
                } else {
                    $message_block.hide();
                    $urly_wurly.show();
                }
            });
        }

    }));