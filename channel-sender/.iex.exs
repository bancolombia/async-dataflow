#alias ChannelSenderEx.Core.{Channel, ChannelRegistry, ChannelSupervisor, ProtocolMessage}
#test_channel_args0 = {"1", "app1", "user1"}
#test_channel_args1 = {"1", "app1", "user1"}
#test_channel_args2 = {"1", "app1", "user1"}
#
#
#{:ok, test_channel0} = ChannelSupervisor.start_channel(test_channel_args0)
#
#new_message = fn -> ProtocolMessage.of("id1"<> UUID.uuid4(), "test.event1", "message data aasda" <> UUID.uuid4())  end
#msg0 = new_message.()
#msg1 = new_message.()

# Crear procesos
#pid = spawn(fn -> IO.puts("Hello") end)

## Enviar mensajes
# Erlang Term: cualquier cosa que se le pueda asignar a una variable
#send(pid, 1)
#send(pid, "Hola procesos kjhkhkjhkjhkhkjhjkhkjhkhkjkhhgjh")
#send(pid, {:atomo, "Hola", []})
#send(pid, [1,2,3,4])
#send(pid, fn  -> IO.puts("Hola") end)
#
#
##Recibir mensajes
#receive do # 1 solo mensaje
#  {:mensaje1, contenido} -> spawn(fn -> Process.sleep(30000); IO.puts(contenido) end)
#  {:mensaje2, contenido} -> IO.puts(contenido)
#  a -> IO.puts(contenido)
#  after
#    1000 -> :ok
#end


#

##Process Links
#new_pid = spawn_link(fn  -> IO.puts("Hello") end)
#spawn(fn  -> IO.puts("Hello") end)
#Process.link(pid)
#
#0      1
#0<---->1 (link)
#0<----1 (kill) exit signal: matar al otro proceso (crash)
#
##System process
#Process.flag(:trap_exit, true)

#0<---->1<---->2<---->3(kill)<---->4<---->5<---->0

#receive do
#  {:msg, msg} ->
#    IO.inspect(:msg)
#    IO.inspect(:msg)
#    IO.inspect(:msg)
#    IO.inspect(:msg)
#    IO.inspect(:msg)
#    IO.inspect(:msg)
#    case msg do
#      {} -> IO.inspect(:hola)
#    end
#  :meg2 ->
#    IO.inspect(1)
#    IO.inspect(1)
#    IO.inspect(1)
#    IO.inspect(2)
#  :meg3 ->
#    IO.inspect(1)
#    IO.inspect(1)
#    IO.inspect(1)
#    IO.inspect(2)
#end

#Process.link(pid)
#
#
#Process.monitor(pid)
#
#spawn_link(fn  -> :ok end)
#spawn_monitor(fn  -> :ok end)
#
#Monitor       Monitoreado
#   0------------->1
#0      1
#0----->1 (monitor)
#0----->1(kill)
#0<-----1  (Send message) :DOWN


#Supervisor ->  Proceso
#lance un hijo (Modulo, funcion, [args]) -> apply()
# * Reiniciar el proceso
# * Max de reinicios (n) -> vamos a matar a todos los procesos del supervisor. Loggear
