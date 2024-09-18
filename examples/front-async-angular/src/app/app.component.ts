import { Component } from '@angular/core';
import { Subscription } from 'rxjs';
import { AsyncClientService } from '../app/services/async-client.service';
import { BusinessService } from '../app/services/business.service';
import { RouterOutlet } from '@angular/router';
import { HttpClientModule } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet,HttpClientModule,CommonModule,FormsModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
  title = 'front-async';
  delay = 5000;
  user_ref = 'UNIQUEID';
  results : string[] = [];
   private eventReceived?: Subscription;

  constructor(
    private asyncClientService: AsyncClientService,
    private businessService: BusinessService
  ) {}

  ngOnInit(): void {
    this.asyncClientService.getCredentials(this.user_ref);
    this.listenEvents();
  }
  generateRequest() {
    let start = performance.now();
    this.businessService
      .callBusinessUseCase(this.delay)
      .subscribe((res: any) => {
        this.results.push(
          `Get empty response after ${performance.now() - start} ms`
        );
      });
  }

  private listenEvents() {
    this.eventReceived = this.asyncClientService.eventRecived$.subscribe(
      (msg) => {
        if (msg.event == 'businessEvent') {
          this.results.push(
            `Message from async dataflow, title: ${msg.payload.title} detail: ${msg.payload.detail}`
          );
        }
      }
    );
  }
}