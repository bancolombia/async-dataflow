import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { CommonModule } from '@angular/common';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatTabsModule } from '@angular/material/tabs';
import { MatIconModule } from '@angular/material/icon';
import { LogsComponent } from "./components/logs/logs.component";
import { RequestsComponent } from './components/requests/requests.component';
import { SettingsComponent } from './components/settings/settings.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, CommonModule, MatToolbarModule, MatIconModule, MatTabsModule, LogsComponent, RequestsComponent, SettingsComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
}