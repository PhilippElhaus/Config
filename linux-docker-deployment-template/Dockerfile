FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base

WORKDIR /app

COPY bin/Release/linux-x64 .
COPY wwwroot /app/wwwroot

EXPOSE 8080

CMD ["dotnet", "CV.dll"]