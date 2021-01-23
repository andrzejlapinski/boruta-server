defmodule BorutaGateway.GatewayPipeline do
  @moduledoc false

  use Plug.Router

  plug BorutaGateway.Plug.AssignUpstream
  plug BorutaGateway.Plug.Authorize
  plug BorutaGateway.Plug.Metrics
  plug Plug.Logger

  plug :match
  plug :dispatch

  match _, to: BorutaGateway.Plug.Handler, init_opts: []
end
