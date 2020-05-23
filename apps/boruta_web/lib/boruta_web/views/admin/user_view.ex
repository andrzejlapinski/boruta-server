defmodule BorutaWeb.Admin.UserView do
  use BorutaWeb, :view

  alias BorutaWeb.Admin.UserView
  alias BorutaIdentityProvider.ResourceOwners

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email,
      authorized_scopes: ResourceOwners.authorized_scopes(user)
    }
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.Scope do
    def encode(scope, opts) do
      Jason.Encode.map(Map.take(scope, [:id, :name, :public]), opts)
    end
  end
end
