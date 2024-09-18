import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { environment } from '../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class BusinessService {
  constructor(private http: HttpClient) {}

  public callBusinessUseCase(delay: number) {
    const url = `${environment.api_business}/business`;
    let httpParams = new HttpParams()
      .set('channel_ref', sessionStorage.getItem('channel_ref')??'')
      .set('delay', delay);
    return this.http.get(url, {
      params: httpParams,
    });
  }
}
