package com.gamellan.eventcountdown.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.gamellan.eventcountdown.R
import es.antonborri.home_widget.HomeWidgetPlugin

class EventCountdownWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val widgetData = HomeWidgetPlugin.getData(context)
            val title = widgetData.getString("title", "Add your first event")
            val days = widgetData.getString("days", "Start counting today")

            val views = RemoteViews(context.packageName, R.layout.event_countdown_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_days, days)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
