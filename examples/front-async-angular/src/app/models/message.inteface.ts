export interface Message {
  correlation_id: string;
  event: string;
  message_id: string;
  payload: any;
}
