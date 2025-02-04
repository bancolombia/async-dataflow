import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { AsyncClient } from '@bancolombia/chanjs-client';
import { Subject } from 'rxjs';
import { Message } from '../models/message.inteface';
import { environment } from '../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class AsyncClientService {
  private getEventFromAsyncDataflow = new Subject<Message>();
  public eventRecived$ = this.getEventFromAsyncDataflow.asObservable();
  private client?: AsyncClient;
  private channel_ref: string = '';
  constructor(private http: HttpClient) { }

  public getCredentials(user_ref: string) {
    const url = `${environment.api_business}/credentials`;

    this.http
      .get(url, { params: { user_ref: user_ref } })
      .subscribe((res: any) => {
        this.channel_ref = res.channelRef;
        this.createChannel(res);
      });
  }

  private createChannel(res: any) {
    this.initChannel(res.channelRef, res.channelSecret);
  }

  private initChannel(channel_ref: string, channel_secret: string) {
    console.log('Opening web socket with channel_ref:', channel_ref);
    this.client = new AsyncClient({
      socket_url: `ws://${environment.socket_url_async}`,
      channel_ref,
      channel_secret,
      heartbeat_interval: environment.heartbeat_interval,
    });

    this.client.connect();
    this.listenEvents(this.client);
  }

  private listenEvents(client: AsyncClient) {
    client.listenEvent('businessEvent', (message) => {
      this.getEventFromAsyncDataflow.next(message);
    });
  }

  public closeChannel() {
    this.client?.disconnect();
  }

  public forceConnect(){
    return this.client?.connect();
  }

  public getRef() {
    return this.channel_ref;
  }
}
