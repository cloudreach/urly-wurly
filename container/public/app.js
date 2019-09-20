(function (init) {
        init(window.jQuery, window, document);

    }(function ($, window, document) {

        // define html elements

            $login_urly_wurly = $('#login-urly-wurly'),
            $logout_urly_wurly = $('#logout-urly-wurly'),

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

        function get_sts_credentials(id_token) {
            // ok we are logged in
            $login_urly_wurly.hide();
            $urly_wurly.show();
            $logout_urly_wurly.show();
        }

    }));