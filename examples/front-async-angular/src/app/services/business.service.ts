import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { environment } from '../environments/environment';
import { AsyncClientService } from './async-client.service';

@Injectable({
  providedIn: 'root',
})
export class BusinessService {
  constructor(private http: HttpClient, private channel: AsyncClientService) { }

  public callBusinessUseCase(delay: number, user_ref: string) {
    const url = `${environment.api_business}/business`;
    let httpParams = new HttpParams()
      .set('channel_ref', this.channel.getRef())
      .set('user_ref', user_ref)
      .set('delay', delay);
    return this.http.get(url, {
      params: httpParams,
    });
  }
}
