defmodule BorutaWeb.Integration.OpenidConnectTest do
  use BorutaWeb.ConnCase, async: false

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias Boruta.Ecto

  describe "OpenID Connect flows" do
    setup %{conn: conn} do
      resource_owner = user_fixture()
      redirect_uri = "http://redirect.uri"
      client = insert(:client, redirect_uris: [redirect_uri])
      scope = insert(:scope, public: true)

      {:ok,
       conn: conn,
       client: client,
       redirect_uri: redirect_uri,
       resource_owner: resource_owner,
       scope: scope}
    end

    test "redirect to login with prompt='login'", %{conn: conn} do
      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            prompt: "login"
          })
        )

      assert redirected_to(conn) =~ "/users/log_out"
    end

    test "redirects to login with prompt='none' without any current_user", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri
    } do
      conn = init_test_session(conn, session_chosen: true)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

    assert redirected_to(conn) =~ ~r/error=login_required/
  end

    test "authorize with prompt='none' and a current_user", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert url = redirected_to(conn)
      assert [_, _id_token] =
               Regex.run(
                 ~r/#{redirect_uri}#id_token=(.+)/,
                 url
               )
    end

    test "logs in with an expired max_age and current_user", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      conn =
        conn
        |> log_in(resource_owner)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: "openid",
            nonce: "nonce",
            max_age: 0
          })
        )

      assert redirected_to(conn) =~ "/users/log_out"
    end

    test "redirects to choose session with a non expired max_age and current_user", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      conn =
        conn
        |> log_in(resource_owner)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: "openid",
            nonce: "nonce",
            max_age: 10
          })
        )

      assert html_response(conn, 200) =~ ~r/choose-session/
    end
  end

  describe "jwks endpoints" do
    test "returns an empty list", %{conn: conn} do
      conn = get(conn, Routes.openid_path(conn, :jwks_index))

      assert json_response(conn, 200) == %{"keys" => []}
    end

    test "returns all clients keys", %{conn: conn} do
      %Ecto.Client{id: client_id} = insert(:client)

      conn = get(conn, Routes.openid_path(conn, :jwks_index))

      assert %{
        "keys" => [%{"kid" => ^client_id}]
      } = json_response(conn, 200)
    end
  end

  describe "Opeind discovery 1.0" do
    test "returns required keys", %{conn: conn} do
      required_keys = [
        "authorization_endpoint",
        "id_token_signing_alg_values_supported",
        "issuer",
        "jwks_uri",
        "response_types_supported",
        "subject_types_supported",
        "token_endpoint"
      ]

      conn = get(conn, Routes.openid_path(conn, :well_known))

      assert json_response(conn, 200) |> Map.keys() == required_keys
      assert json_response(conn, 200) == %{
        "authorization_endpoint" => "boruta/oauth/authorize",
        "id_token_signing_alg_values_supported" => ["RS512"],
        "issuer" => "boruta",
        "jwks_uri" => "boruta/openid/jwks",
        "response_types_supported" => ["client_credentials", "password", "authorization_code", "refresh_token", "implicit", "revoke", "introspect"],
        "subject_types_supported" => ["public"],
        "token_endpoint" => "boruta/oauth/token"
      }
    end
  end
end
