---functions---

req_pq#60469778 nonce:int128 = ResPQ;
req_DH_params#d712e4be nonce:int128 server_nonce:int128 p:bytes q:bytes public_key_fingerprint:long encrypted_data:bytes = Server_DH_Params;
set_client_DH_params#f5045f1f nonce:int128 server_nonce:int128 encrypted_data:bytes = Set_client_DH_params_answer;
ping#7abe77ec ping_id:long = Pong;
ping_delay_disconnect#f3427b8c ping_id:long disconnect_delay:int = Pong;
destroy_session#e7512126 session_id:long = DestroySessionRes;
destroy_sessions#a13dc52f session_ids:vector<long> = DestroySessionsRes;
get_future_salts#b921bd04 num:int = FutureSalts;
rpc_drop_answer#58e4a740 req_msg_id:long = RpcDropAnswer;
