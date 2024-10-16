defmodule BorutaWeb.Oauth.IntrospectTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "introspect" do
    setup %{conn: conn} do
      client = insert(:client)
      client_token = insert(:token, type: "access_token", client: client, scope: "")
      resource_owner = user_fixture()

      resource_owner_token =
        insert(:token,
          type: "access_token",
          client: client,
          sub: resource_owner.id,
          scope: ""
        )

      {:ok,
       conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded"),
       client: client,
       client_token: client_token,
       resource_owner_token: resource_owner_token,
       resource_owner: resource_owner}
    end

    test "returns an error if request is invalid", %{conn: conn} do
      conn =
        post(
          conn,
          "/oauth/introspect"
        )

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "error_description" =>
                 "Request validation failed. Required properties client_id, token are missing at #."
             }
    end

    test "returns an error if client is invalid", %{conn: conn, client: client} do
      conn =
        post(
          conn,
          "/oauth/introspect",
          "client_id=#{client.id}&client_secret=bad_secret&token=token"
        )

      assert json_response(conn, 401) == %{
               "error" => "invalid_client",
               "error_description" => "Invalid client_id or client_secret."
             }
    end

    test "returns an inactive token response if token is invalid", %{conn: conn, client: client} do
      conn =
        post(
          conn,
          "/oauth/introspect",
          "client_id=#{client.id}&client_secret=#{client.secret}&token=bad_token"
        )

      assert json_response(conn, 200) == %{"active" => false}
    end

    test "returns an introspect token response if client, token are valid", %{
      conn: conn,
      client: client,
      client_token: token
    } do
      conn =
        post(
          conn,
          "/oauth/introspect",
          "client_id=#{client.id}&client_secret=#{client.secret}&token=#{token.value}"
        )

      assert json_response(conn, 200) == %{
               "active" => true,
               "client_id" => client.id,
               "exp" => token.expires_at,
               "iat" => DateTime.to_unix(token.inserted_at),
               "iss" => "http://localhost:4000",
               "scope" => token.scope,
               "sub" => nil,
               "username" => nil
             }
    end

    test "returns an introspect token response if resource owner token is valid", %{
      conn: conn,
      client: client,
      resource_owner_token: token,
      resource_owner: resource_owner
    } do
      conn =
        post(
          conn,
          "/oauth/introspect",
          "client_id=#{client.id}&client_secret=#{client.secret}&token=#{token.value}"
        )

      assert json_response(conn, 200) == %{
               "active" => true,
               "client_id" => client.id,
               "exp" => token.expires_at,
               "iat" => DateTime.to_unix(token.inserted_at),
               "iss" => "http://localhost:4000",
               "scope" => token.scope,
               "sub" => resource_owner.id,
               "username" => resource_owner.username
             }
    end

    test "returns a jwt token when accept header set", %{
      conn: conn,
      client: client,
      client_token: token
    } do
      signer = Joken.Signer.create("RS512", %{"pem" => client.public_key})
      conn = put_req_header(conn, "accept", "application/jwt")

      conn =
        post(
          conn,
          "/oauth/introspect",
          "client_id=#{client.id}&client_secret=#{client.secret}&token=#{token.value}"
        )

      case Joken.Signer.verify(response(conn, 200), signer) do
        {:ok, payload} ->
          assert payload == %{
                   "active" => true,
                   "client_id" => client.id,
                   "exp" => token.expires_at,
                   "iat" => DateTime.to_unix(token.inserted_at),
                   "iss" => "http://localhost:4000",
                   "scope" => token.scope,
                   "sub" => nil,
                   "username" => nil
                 }

        _ ->
          assert false
      end
    end
  end
end
